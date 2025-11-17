#include "playlistmodel.h"
#include <QDir>
#include <QFileInfo>
#include <QRegularExpression>
#include <QDebug>
#include <QMediaPlayer>
#include <QAudioOutput>
#include <QEventLoop>
#include <QTimer>
#include <QMediaMetaData>
#include <QImage>
#include <QDateTime>

static const QStringList AUDIO_EXTS = { ".mp3", ".m4a", ".wav", ".flac", ".ogg" };

PlaylistModel::PlaylistModel(QObject *parent)
    : QAbstractListModel(parent)
{}

int PlaylistModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_items.size();
}

QVariant PlaylistModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid()) return {};
    int row = index.row();
    if (row < 0 || row >= m_items.size()) return {};

    const TrackItem &it = m_items[row];
    switch (role) {
    case IndexRole: return row;
    case NameRole: return it.name;
    case TitleRole: return it.title;
    case ArtistRole: return it.artist;
    case AlbumRole: return it.album;
    case LyricsRole: return it.lyrics;
    case UrlRole: return it.url.toString();
    case DurationRole: return it.duration;
    case CoverRole: return it.cover;
    default: return {};
    }
}

QHash<int, QByteArray> PlaylistModel::roleNames() const
{
    QHash<int, QByteArray> r;
    r[IndexRole] = "index";
    r[NameRole] = "name";
    r[TitleRole] = "title";
    r[ArtistRole] = "artist";
    r[AlbumRole] = "album";
    r[LyricsRole] = "lyrics";
    r[UrlRole] = "url";
    r[DurationRole] = "duration";
    r[CoverRole] = "cover";
    return r;
}

void PlaylistModel::clear()
{
    beginResetModel();
    m_items.clear();
    endResetModel();
}

QPair<QString, QString> PlaylistModel::parseFileName(const QString &fileName) const
{
    // Try "01 - Title - Artist", "Title - Artist", else filename -> title
    QString base = QFileInfo(fileName).completeBaseName();
    QStringList parts = base.split(" - ");
    if (parts.size() >= 3) {
        return { parts.at(1).trimmed(), parts.at(2).trimmed() };
    } else if (parts.size() == 2) {
        return { parts.at(0).trimmed(), parts.at(1).trimmed() };
    } else {
        return { base.trimmed(), QString() };
    }
}

void PlaylistModel::addFile(const QString &filePath)
{
    QFileInfo fi(filePath);
    QString ext = fi.suffix().toLower();
    if (!AUDIO_EXTS.contains("." + ext)) return;

    TrackItem it;
    it.url = QUrl::fromLocalFile(fi.absoluteFilePath());
    it.duration = 0;
    it.cover = "qrc:/assets/default_cover.svg";

    // 使用文件名作为后备
    QString baseName = fi.completeBaseName();
    it.name = baseName;
    
    // 初始化为文件名解析结果
    QPair<QString, QString> parsed = parseFileName(fi.fileName());
    it.title = parsed.first.isEmpty() ? baseName : parsed.first;
    it.artist = parsed.second.isEmpty() ? "Unknown Artist" : parsed.second;
    
    // 防止title和artist相同
    if (it.artist == it.title) {
        it.artist = "Unknown Artist";
    }
    
    // 尝试从元数据提取信息
    bool metadataLoaded = false;
    
    // 创建临时播放器来提取元数据
    QMediaPlayer tempPlayer;
    QAudioOutput tempAudioOutput;
    tempPlayer.setAudioOutput(&tempAudioOutput);
    
    // 同步等待元数据（使用事件循环）
    QEventLoop loop;
    QTimer timer;
    timer.setSingleShot(true);
    timer.setInterval(5000); // 增加超时时间到5秒
    
    QObject::connect(&tempPlayer, &QMediaPlayer::mediaStatusChanged, [&](QMediaPlayer::MediaStatus status) {
        if (status == QMediaPlayer::LoadedMedia || status == QMediaPlayer::BufferedMedia) {
            metadataLoaded = true;
            
            // 提取元数据
            auto metaData = tempPlayer.metaData();
            
            // 提取标题
            if (metaData.value(QMediaMetaData::Title).isValid()) {
                QString extractedTitle = metaData.value(QMediaMetaData::Title).toString();
                if (!extractedTitle.isEmpty()) {
                    it.title = extractedTitle;
                }
            }
            
            // 提取艺术家
            QString extractedArtist;
            if (metaData.value(QMediaMetaData::Author).isValid()) {
                extractedArtist = metaData.value(QMediaMetaData::Author).toString();
            } else if (metaData.value(QMediaMetaData::AlbumArtist).isValid()) {
                extractedArtist = metaData.value(QMediaMetaData::AlbumArtist).toString();
            } else if (metaData.value(QMediaMetaData::ContributingArtist).isValid()) {
                extractedArtist = metaData.value(QMediaMetaData::ContributingArtist).toString();
            }
            
            if (!extractedArtist.isEmpty()) {
                it.artist = extractedArtist;
            }
            
            // 提取唱片集
            if (metaData.value(QMediaMetaData::AlbumTitle).isValid()) {
                it.album = metaData.value(QMediaMetaData::AlbumTitle).toString();
            }
            
            // 提取时长
            if (metaData.value(QMediaMetaData::Duration).isValid()) {
                it.duration = metaData.value(QMediaMetaData::Duration).toInt();
            }
            
            // 提取歌词 - 尝试多种可能的键名
            QString lyricsText;
            
            // 尝试遍历所有元数据查找歌词相关内容
            auto keys = metaData.keys();
            for (auto metaKey : keys) {
                QVariant value = metaData.value(metaKey);
                if (value.isValid() && value.canConvert<QString>()) {
                    QString valueStr = value.toString();
                    // 检查是否包含歌词内容（通常歌词文本较长且包含换行符）
                    if (valueStr.length() > 50 && 
                        (valueStr.contains('\n') || valueStr.contains('\r') || 
                         valueStr.contains("lyric", Qt::CaseInsensitive) ||
                         valueStr.contains("text", Qt::CaseInsensitive))) {
                        lyricsText = valueStr;
                        break;
                    }
                }
            }
            
            if (!lyricsText.isEmpty()) {
                it.lyrics = lyricsText;
            }
            
            // 提取封面 - 尝试多种可能的键名
            QImage coverImage;
            
            // 尝试 CoverArtImage
            if (metaData.value(QMediaMetaData::CoverArtImage).isValid()) {
                QVariant coverVariant = metaData.value(QMediaMetaData::CoverArtImage);
                coverImage = coverVariant.value<QImage>();
            }
            // 尝试 ThumbnailImage
            else if (metaData.value(QMediaMetaData::ThumbnailImage).isValid()) {
                QVariant coverVariant = metaData.value(QMediaMetaData::ThumbnailImage);
                coverImage = coverVariant.value<QImage>();
            }
            
            if (!coverImage.isNull()) {
                // 保存封面到临时文件
                QString tempPath = QDir::tempPath() + "/music_cover_" + QString::number(QDateTime::currentMSecsSinceEpoch()) + ".jpg";
                if (coverImage.save(tempPath, "JPG", 90)) {
                    it.cover = "file:///" + tempPath;
                    qDebug() << "PlaylistModel::addFile - 封面已保存到:" << it.cover;
                } else {
                    qDebug() << "PlaylistModel::addFile - 封面保存失败";
                }
            } else {
                qDebug() << "PlaylistModel::addFile - 未找到封面图片，使用默认封面:" << it.cover;
            }
            
            // 最终检查：防止title和artist相同
            if (it.artist == it.title) {
                it.artist = "Unknown Artist";
            }
            
            loop.quit();
        } else if (status == QMediaPlayer::InvalidMedia) {
            loop.quit();
        }
    });
    
    QObject::connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
    
    timer.start();
    tempPlayer.setSource(it.url);
    
    // 不调用play()，只设置源就足够触发元数据加载
    loop.exec();
    
    if (!metadataLoaded) {
        // 静默处理超时情况
    }

    beginInsertRows({}, m_items.size(), m_items.size());
    m_items.append(it);
    endInsertRows();
}

void PlaylistModel::loadFolder(const QString &folderPath)
{
    QDir dir(folderPath);
    if (!dir.exists()) return;

    beginResetModel();
    m_items.clear();

    QFileInfoList entries = QDir(folderPath).entryInfoList(QDir::Files | QDir::NoDotAndDotDot, QDir::Name);
    for (const QFileInfo &fi : entries) {
        addFile(fi.absoluteFilePath());
    }

    // Also walk subfolders if desired: (commented out)
    // QDirIterator it(folderPath, QDirIterator::Subdirectories);

    endResetModel();
}

QVariantMap PlaylistModel::get(int idx) const
{
    QVariantMap map;
    if (idx < 0 || idx >= m_items.size()) return map;
    const TrackItem &t = m_items[idx];
    map["name"] = t.name;
    map["title"] = t.title;
    map["artist"] = t.artist;
    map["album"] = t.album;
    map["lyrics"] = t.lyrics;
    map["url"] = t.url.toString();
    map["duration"] = t.duration;
    map["cover"] = t.cover;
    return map;
}