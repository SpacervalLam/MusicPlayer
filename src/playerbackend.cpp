#include "playerbackend.h"
#include <QUrl>
#include <QFile>
#include <QDebug>
#include <QRandomGenerator>
#include <QCursor>
#include <QSettings>
#include <QDir>
#include <QRegularExpression>
#include <QStringList>
#include <QKeyEvent>
#include <QApplication>
#include <cmath>

PlayerBackend::PlayerBackend(PlaylistModel *playlist, QObject *parent)
    : QObject(parent)
    , m_playlist(playlist)
    , m_playMode(0) // Default to Sequential mode
{
    m_player = new QMediaPlayer(this);
    m_audioOutput = new QAudioOutput(this);
    m_player->setAudioOutput(m_audioOutput);
    
    // 设置音量为最大值
    m_audioOutput->setVolume(1.0);

    // setup audio buffer read - 使用 QMediaPlayer 的状态变化来启动音频设备
    connect(m_player, &QMediaPlayer::playbackStateChanged, this, [this](QMediaPlayer::PlaybackState state){
        if (state == QMediaPlayer::PlayingState) {
            // 启动音频设备读取
            if (!m_fftTimer) {
                m_fftTimer = new QTimer(this);
                m_fftTimer->setInterval(16); // 60fps
                connect(m_fftTimer, &QTimer::timeout, this, &PlayerBackend::updateSpectrum);
            }
            m_fftTimer->start();
        } else {
            if (m_fftTimer) {
                m_fftTimer->stop();
            }
        }
    });

    // 安装事件过滤器来处理ESC键
    if (QApplication::instance()) {
        QApplication::instance()->installEventFilter(this);
    }

    // Timer to simulate audio level updates (since QAudioProbe is not available in Qt 6)
    m_audioLevelTimer = new QTimer(this);
    m_audioLevelTimer->setInterval(25); // Update every 25ms for more responsive visualization
    connect(m_audioLevelTimer, &QTimer::timeout, this, &PlayerBackend::updateAudioLevel);

    connect(m_player, &QMediaPlayer::positionChanged, this, &PlayerBackend::onPositionChanged);
    connect(m_player, &QMediaPlayer::durationChanged, this, &PlayerBackend::onDurationChanged);
    connect(m_player, &QMediaPlayer::playbackStateChanged, this, &PlayerBackend::onPlaybackStateChanged);
    connect(m_player, &QMediaPlayer::mediaStatusChanged, this, &PlayerBackend::onMediaStatusChanged);
    
    // 延迟加载设置和歌单，让界面先显示
    QTimer::singleShot(100, this, &PlayerBackend::delayedInit);
}

bool PlayerBackend::isPlaying() const
{
    return m_player->playbackState() == QMediaPlayer::PlayingState;
}

qint64 PlayerBackend::position() const
{
    return m_player->position();
}

qint64 PlayerBackend::duration() const
{
    return m_player->duration();
}

void PlayerBackend::play()
{
    m_player->play();
    m_audioLevelTimer->start();
    emit isPlayingChanged(true);
}

void PlayerBackend::pause()
{
    m_player->pause();
    m_audioLevelTimer->stop();
    m_audioLevel = 0.0;
    emit audioLevelChanged();
    emit isPlayingChanged(false);
}

void PlayerBackend::togglePlay()
{
    if (m_player->playbackState() == QMediaPlayer::PlayingState) pause();
    else play();
}

void PlayerBackend::next()
{
    if (!m_playlist) return;
    int count = m_playlist->rowCount();
    if (count == 0) return;
    
    int idx;
    switch (m_playMode) {
    case 1: // Loop One
        idx = m_index; // Stay on current track
        break;
    case 2: // Loop All
        idx = (m_index + 1) % count;
        break;
    case 3: // Random
        idx = QRandomGenerator::global()->bounded(count);
        break;
    default:
        idx = (m_index + 1) % count; // Default to Loop All behavior
        break;
    }
    playIndex(idx);
}

void PlayerBackend::previous()
{
    if (!m_playlist) return;
    int count = m_playlist->rowCount();
    if (count == 0) return;
    int idx = (m_index - 1 + count) % count;
    playIndex(idx);
}

void PlayerBackend::setPosition(qint64 ms)
{
    m_player->setPosition(ms);
}

void PlayerBackend::playIndex(int idx)
{
    if (!m_playlist) return;
    QVariantMap info = m_playlist->get(idx);
    if (info.isEmpty()) return;

    m_index = idx;
    emit currentIndexChanged(m_index);

    QString urlStr = info.value("url").toString();
    QUrl url(urlStr);
    m_player->setSource(url);

    m_title = info.value("title").toString();
    m_artist = info.value("artist").toString();
    m_album = info.value("album").toString();
    m_lyrics = info.value("lyrics").toString();
    m_cover = info.value("cover").toString();

    // 解析歌词
    m_parsedLyrics = parseLyrics(m_lyrics);
    m_currentLyrics.clear();
    m_nextLyrics.clear();
    m_lastLyricPosition = -1;

    emit titleChanged();
    emit artistChanged();
    emit albumChanged();
    emit lyricsChanged();
    emit currentLyricsChanged();
    emit nextLyricsChanged();
    emit coverChanged();

    // try to play immediately
    m_player->play();
}

void PlayerBackend::importFolder(const QString &folderPath)
{
    if (!m_playlist) return;
    m_playlist->loadFolder(folderPath);
    
    // 保存音乐文件夹路径
    setMusicFolder(folderPath);
}

// signals handlers
void PlayerBackend::onPositionChanged(qint64 pos)
{
    emit positionChanged(pos);
    updateLyrics(pos);
}

void PlayerBackend::onDurationChanged(qint64 dur)
{
    emit durationChanged(dur);
}

void PlayerBackend::onPlaybackStateChanged(QMediaPlayer::PlaybackState st)
{
    if (st == QMediaPlayer::PlayingState) {
        m_audioLevelTimer->start();
    } else {
        m_audioLevelTimer->stop();
        m_audioLevel = 0.0;
        emit audioLevelChanged();
    }
    emit isPlayingChanged(st == QMediaPlayer::PlayingState);
}

void PlayerBackend::onMediaStatusChanged(QMediaPlayer::MediaStatus st)
{
    Q_UNUSED(st)
    // could read metadata here (QMediaMetaData) and update title/artist/cover if available
    
    // Handle end of media for different play modes
    if (st == QMediaPlayer::EndOfMedia) {
        if (m_playMode == 1) { // Loop One
            // Restart the current track
            m_player->setPosition(0);
            m_player->play();
        } else if (m_playMode == 2) { // Loop All
            // Play next track (will wrap around to first if at end)
            next();
        } else if (m_playMode == 3) { // Random
            // Play random track
            next();
        } else {
            // Default behavior - treat as Loop All
            next();
        }
    }
}

// Simulated audio level update (since QAudioProbe is not available in Qt 6)
void PlayerBackend::updateAudioLevel()
{
    // Generate a more realistic simulated audio level for visualization purposes
    // In a real implementation, you might use platform-specific audio APIs
    static double phase = 0.0;
    static double beatPhase = 0.0;
    static double lastLevel = 0.0;
    
    phase += 0.15;  // Faster base frequency for more responsiveness
    beatPhase += 0.08;  // Slower beat frequency
    
    // Create multiple frequency components for more realistic audio simulation
    double baseLevel = 0.1;  // Lower base level for better dynamic range
    double highFreq = 0.3 * (sin(phase * 2.3) * 0.5 + 0.5);  // High frequency component
    double midFreq = 0.4 * (sin(phase * 1.2) * 0.5 + 0.5);   // Mid frequency component
    double lowFreq = 0.6 * (sin(beatPhase) * 0.5 + 0.5);     // Low frequency (bass/beat)
    
    // Combine frequencies with emphasis on beats
    double level = baseLevel + highFreq + midFreq + lowFreq;
    
    // Add beat emphasis (periodic spikes)
    double beatIntensity = (sin(beatPhase * 0.5) * 0.5 + 0.5);
    if (beatIntensity > 0.7) {
        level += 0.3 * beatIntensity;  // Beat emphasis
    }
    
    // Add controlled randomness for more natural variation
    level += QRandomGenerator::global()->bounded(100) / 500.0 - 0.1;
    
    // Smooth the transition to avoid jarring changes
    double smoothingFactor = 0.7;
    level = lastLevel * smoothingFactor + level * (1.0 - smoothingFactor);
    
    // Clamp to valid range
    if (level > 1.0) level = 1.0;
    if (level < 0.0) level = 0.0;
    
    lastLevel = level;
    m_audioLevel = level;
    emit audioLevelChanged();
}

void PlayerBackend::updateGlobalMousePosition()
{
    QPoint cursorPos = QCursor::pos();
    if (cursorPos.x() != m_globalMouseX || cursorPos.y() != m_globalMouseY) {
        m_globalMouseX = cursorPos.x();
        m_globalMouseY = cursorPos.y();
        emit globalMouseXChanged();
        emit globalMouseYChanged();
    }
}

void PlayerBackend::setBackgroundImage(const QString &imagePath)
{
    if (m_backgroundImage != imagePath) {
        // 检查文件是否存在
        if (QFile::exists(imagePath)) {
            m_backgroundImage = imagePath;
            emit backgroundImageChanged();
            // 保存设置
            saveSettings();
        } else {
            qWarning() << "Background image file does not exist:" << imagePath;
        }
    }
}

void PlayerBackend::resetBackgroundImage()
{
    if (!m_backgroundImage.isEmpty()) {
        m_backgroundImage.clear();
        emit backgroundImageChanged();
        // 保存设置
        saveSettings();
    }
}

void PlayerBackend::setMusicFolder(const QString &folderPath)
{
    if (m_musicFolder != folderPath) {
        // 检查目录是否存在
        if (QDir(folderPath).exists()) {
            m_musicFolder = folderPath;
            emit musicFolderChanged();
            // 保存设置
            saveSettings();
        } else {
            qWarning() << "Music folder does not exist:" << folderPath;
        }
    }
}

void PlayerBackend::saveSettings()
{
    QSettings settings("MusicPlayer", "Settings");
    
    // 保存背景图片路径
    if (!m_backgroundImage.isEmpty()) {
        settings.setValue("backgroundImage", m_backgroundImage);
    } else {
        settings.remove("backgroundImage");
    }
    
    // 保存背景图片列表
    if (!m_backgroundImageList.isEmpty()) {
        settings.setValue("backgroundImageList", m_backgroundImageList);
    } else {
        settings.remove("backgroundImageList");
    }
    
    // 保存当前背景图片索引
    settings.setValue("currentBackgroundIndex", m_currentBackgroundIndex);
    
    // 保存音乐文件夹路径
    if (!m_musicFolder.isEmpty()) {
        settings.setValue("musicFolder", m_musicFolder);
    } else {
        settings.remove("musicFolder");
    }
    
    // 保存播放模式
    settings.setValue("playMode", m_playMode);
    
    // 保存音量和静音设置
    settings.setValue("volume", m_volume);
    settings.setValue("isMuted", m_isMuted);
}

void PlayerBackend::loadSettings()
{
    QSettings settings("MusicPlayer", "Settings");
    
    // 加载背景图片路径
    QString savedBackgroundImage = settings.value("backgroundImage").toString();
    if (!savedBackgroundImage.isEmpty() && QFile::exists(savedBackgroundImage)) {
        m_backgroundImage = savedBackgroundImage;
        emit backgroundImageChanged();
    }
    
    // 加载背景图片列表
    m_backgroundImageList = settings.value("backgroundImageList", QStringList()).toStringList();
    emit backgroundImageListChanged();
    
    // 加载当前背景图片索引
    m_currentBackgroundIndex = settings.value("currentBackgroundIndex", -1).toInt();
    emit currentBackgroundIndexChanged();
    
    // 加载音乐文件夹路径
    QString savedMusicFolder = settings.value("musicFolder").toString();
    if (!savedMusicFolder.isEmpty() && QDir(savedMusicFolder).exists()) {
        m_musicFolder = savedMusicFolder;
        emit musicFolderChanged();
        
        // 自动加载音乐文件夹中的歌曲
        if (m_playlist) {
            m_playlist->loadFolder(m_musicFolder);
        }
    } else {
        // 如果没有设置音乐文件夹或文件夹不存在，发出信号提示用户选择
        emit musicFolderNeeded();
    }
    
    // 加载播放模式
    int savedPlayMode = settings.value("playMode", 1).toInt(); // Default to 1 (Loop One)
    if (savedPlayMode >= 1 && savedPlayMode <= 3) {
        m_playMode = savedPlayMode;
        emit playModeChanged();
    } else {
        // If invalid mode (like old mode 0), set to Loop One
        m_playMode = 1;
        emit playModeChanged();
    }
    
    // 加载音量和静音设置
    double savedVolume = settings.value("volume", 1.0).toDouble();
    bool savedMuted = settings.value("isMuted", false).toBool();
    
    m_volume = qMax(0.0, qMin(1.0, savedVolume));
    m_isMuted = savedMuted;
    
    if (m_audioOutput) {
        m_audioOutput->setVolume(m_isMuted ? 0.0 : m_volume);
    }
    
    emit volumeChanged();
    emit isMutedChanged();
}

void PlayerBackend::updateLyrics(qint64 position)
{
    if (m_parsedLyrics.isEmpty()) {
        return;
    }

    QString newCurrentLyrics;
    QString newNextLyrics;

    for (int i = 0; i < m_parsedLyrics.size(); ++i) {
        QString line = m_parsedLyrics[i];
        
        // 解析时间戳和歌词 [mm:ss.xxx]歌词内容
        QRegularExpression re(R"(^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$)");
        QRegularExpressionMatch match = re.match(line);
        
        if (match.hasMatch()) {
            int minutes = match.captured(1).toInt();
            int seconds = match.captured(2).toInt();
            int milliseconds = match.captured(3).toInt();
            QString lyric = match.captured(4).trimmed();
            
            qint64 lyricTime = (minutes * 60 + seconds) * 1000 + milliseconds;
            
            if (lyricTime <= position) {
                newCurrentLyrics = lyric;
                // 查找下一句歌词
                if (i + 1 < m_parsedLyrics.size()) {
                    QString nextLine = m_parsedLyrics[i + 1];
                    QRegularExpressionMatch nextMatch = re.match(nextLine);
                    if (nextMatch.hasMatch()) {
                        newNextLyrics = nextMatch.captured(4).trimmed();
                    }
                }
            } else {
                break;
            }
        }
    }

    // 只有当歌词发生变化时才更新
    if (m_currentLyrics != newCurrentLyrics || m_nextLyrics != newNextLyrics) {
        m_currentLyrics = newCurrentLyrics;
        m_nextLyrics = newNextLyrics;
        emit currentLyricsChanged();
        emit nextLyricsChanged();
    }
}

QStringList PlayerBackend::parseLyrics(const QString &lyricsText)
{
    QStringList parsedLines;
    
    if (lyricsText.isEmpty()) {
        return parsedLines;
    }

    QStringList lines = lyricsText.split('\n', Qt::SkipEmptyParts);
    
    for (const QString &line : lines) {
        QString trimmedLine = line.trimmed();
        if (!trimmedLine.isEmpty()) {
            // 检查是否是时间戳格式 [mm:ss.xxx] 或 [mm:ss.xx]
            QRegularExpression re(R"(^\[\d{2}:\d{2}\.\d{2,3}\])");
            if (re.match(trimmedLine).hasMatch()) {
                parsedLines.append(trimmedLine);
            }
        }
    }
    
    return parsedLines;
}

void PlayerBackend::delayedInit()
{
    // 异步加载设置和歌单，不阻塞界面显示
    loadSettings();
    if (!m_musicFolder.isEmpty()) {
        // 使用 QTimer 延迟加载歌单，让界面完全显示后再开始加载
        QTimer::singleShot(50, this, [this]() {
            m_playlist->loadFolder(m_musicFolder);
        });
    }
}

void PlayerBackend::setPlayMode(int mode)
{
    if (m_playMode != mode && mode >= 1 && mode <= 3) {
        m_playMode = mode;
        emit playModeChanged();
        saveSettings();
    }
}

void PlayerBackend::togglePlayMode()
{
    int nextMode;
    if (m_playMode < 1 || m_playMode > 3) {
        nextMode = 1; // Default to Loop One if invalid mode
    } else {
        nextMode = m_playMode + 1;
        if (nextMode > 3) nextMode = 1; // Loop back to 1 (Loop One)
    }
    setPlayMode(nextMode);
}

void PlayerBackend::updateSpectrum()
{
    // 由于 Qt 6 中无法直接获取 PCM 数据，我们基于音频级别生成模拟频谱
    // 这将创建一个更真实的频谱效果，与音频级别同步
    
    // 清空频谱数据 - 更新为60个频段以匹配QML中的barCount
    m_spectrum.fill(0.0, 60);
    
    if (!isPlaying() || m_audioLevel < 0.01) {
        emit spectrumChanged();
        return;
    }
    
    // 基于音频级别生成频谱数据
    // 低频部分通常更强，高频部分较弱
    for (int i = 0; i < 60; ++i) {
        double baseValue = m_audioLevel;
        
        // 创建频率分布：低频强，高频弱
        double frequencyFactor = 1.0 - (i / 60.0) * 0.7; // 低频1.0，高频0.3
        
        // 添加随机变化使频谱更生动
        double randomFactor = 0.7 + (QRandomGenerator::global()->bounded(100) / 100.0) * 0.6;
        
        // 添加时间变化
        double timeFactor = 0.8 + 0.2 * sin(QDateTime::currentMSecsSinceEpoch() / 200.0 + i * 0.5);
        
        // 计算最终频谱值
        double spectrumValue = baseValue * frequencyFactor * randomFactor * timeFactor;
        
        // 确保值在合理范围内
        spectrumValue = qMax(0.0, qMin(1.0, spectrumValue));
        
        m_spectrum[i] = spectrumValue;
    }
    
    // 添加一些峰值效果
    if (m_audioLevel > 0.5) {
        int peakCount = QRandomGenerator::global()->bounded(3) + 1;
        for (int i = 0; i < peakCount; ++i) {
            int peakIndex = QRandomGenerator::global()->bounded(60);
            m_spectrum[peakIndex] = qMin(1.0, m_spectrum[peakIndex] * 1.5);
        }
    }
    
    emit spectrumChanged();
}

QVariantList PlayerBackend::spectrum() const
{
    QVariantList list;
    for (double v : m_spectrum) list.append(v);
    return list;
}

double PlayerBackend::volume() const
{
    return m_volume;
}

bool PlayerBackend::isMuted() const
{
    return m_isMuted;
}

void PlayerBackend::setVolume(double volume)
{
    if (m_volume != volume) {
        m_volume = qMax(0.0, qMin(1.0, volume));
        if (m_audioOutput) {
            m_audioOutput->setVolume(m_isMuted ? 0.0 : m_volume);
        }
        emit volumeChanged();
        saveSettings();
    }
}

void PlayerBackend::setMuted(bool muted)
{
    if (m_isMuted != muted) {
        m_isMuted = muted;
        if (m_audioOutput) {
            m_audioOutput->setVolume(m_isMuted ? 0.0 : m_volume);
        }
        emit isMutedChanged();
        saveSettings();
    }
}

void PlayerBackend::toggleMute()
{
    setMuted(!m_isMuted);
}

bool PlayerBackend::eventFilter(QObject *obj, QEvent *event)
{
    if (event->type() == QEvent::KeyPress) {
        QKeyEvent *keyEvent = static_cast<QKeyEvent*>(event);
        qDebug() << "Key pressed:" << keyEvent->key() << "Text:" << keyEvent->text();
        
        if (keyEvent->key() == Qt::Key_Escape) {
            qDebug() << "ESC key detected, emitting escapeKeyPressed signal";
            emit escapeKeyPressed();
            return true; // 事件已处理
        }
        else if (keyEvent->key() == Qt::Key_Space) {
            qDebug() << "Space key detected, toggling play/pause";
            togglePlay();
            return true; // 事件已处理
        }
        else if (keyEvent->key() == Qt::Key_Z && (keyEvent->modifiers() & Qt::ControlModifier)) {
            qDebug() << "Ctrl+Z detected, playing previous track";
            previous();
            return true; // 事件已处理
        }
        else if (keyEvent->key() == Qt::Key_X && (keyEvent->modifiers() & Qt::ControlModifier)) {
            qDebug() << "Ctrl+X detected, playing next track";
            next();
            return true; // 事件已处理
        }
        else if (keyEvent->key() == Qt::Key_F && (keyEvent->modifiers() & Qt::ControlModifier)) {
            qDebug() << "Ctrl+F detected, toggling search mode";
            emit toggleSearchMode();
            return true; // 事件已处理
        }
    }
    return QObject::eventFilter(obj, event);
}

// 背景图片管理方法
void PlayerBackend::addBackgroundImage(const QString &imagePath)
{
    if (QFile::exists(imagePath) && !m_backgroundImageList.contains(imagePath)) {
        m_backgroundImageList.append(imagePath);
        emit backgroundImageListChanged();
        
        // 如果是第一张图片，设置为当前背景
        if (m_backgroundImageList.size() == 1) {
            setBackgroundImage(imagePath);
            m_currentBackgroundIndex = 0;
            emit currentBackgroundIndexChanged();
        }
        
        saveSettings();
    }
}

void PlayerBackend::addBackgroundImages(const QStringList &imagePaths)
{
    bool hasNewImages = false;
    
    for (const QString &imagePath : imagePaths) {
        if (QFile::exists(imagePath) && !m_backgroundImageList.contains(imagePath)) {
            m_backgroundImageList.append(imagePath);
            hasNewImages = true;
            
            // 如果是第一张图片，设置为当前背景
            if (m_backgroundImageList.size() == 1) {
                setBackgroundImage(imagePath);
                m_currentBackgroundIndex = 0;
                emit currentBackgroundIndexChanged();
            }
        }
    }
    
    if (hasNewImages) {
        emit backgroundImageListChanged();
        saveSettings();
    }
}



void PlayerBackend::setBackgroundByIndex(int index)
{
    if (index >= 0 && index < m_backgroundImageList.size()) {
        setBackgroundImage(m_backgroundImageList[index]);
        m_currentBackgroundIndex = index;
        emit currentBackgroundIndexChanged();
    }
}

void PlayerBackend::removeBackgroundImageByIndex(int index)
{
    if (index < 0 || index >= m_backgroundImageList.size()) {
        return;
    }
    
    // 移除指定索引的图片
    m_backgroundImageList.removeAt(index);
    
    // 如果移除的是当前背景图片
    if (index == m_currentBackgroundIndex) {
        if (m_backgroundImageList.isEmpty()) {
            // 没有更多图片，重置背景
            resetBackgroundImage();
            m_currentBackgroundIndex = -1;
        } else {
            // 设置为下一张图片（或最后一张如果移除的是最后一张）
            int newIndex = qMin(index, m_backgroundImageList.size() - 1);
            setBackgroundByIndex(newIndex);
        }
    } else if (index < m_currentBackgroundIndex) {
        // 如果移除的图片在当前背景之前，需要调整当前背景索引
        m_currentBackgroundIndex--;
        emit currentBackgroundIndexChanged();
    }
    
    emit backgroundImageListChanged();
    saveSettings();
}

#include "playerbackend.moc"