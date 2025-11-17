#ifndef PLAYERBACKEND_H
#define PLAYERBACKEND_H

#include <QObject>
#include <QMediaPlayer>
#include <QAudioOutput>
#include <QTimer>
#include <QVariant>
#include <QSettings>
#include <QTimer>
#include <QDateTime>
#include <QRandomGenerator>
#include <QVector>
#include "playlistmodel.h"

class PlayerBackend : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int currentIndex READ currentIndex NOTIFY currentIndexChanged)
    Q_PROPERTY(bool isPlaying READ isPlaying NOTIFY isPlayingChanged)
    Q_PROPERTY(qint64 position READ position NOTIFY positionChanged)
    Q_PROPERTY(qint64 duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(QString title READ title NOTIFY titleChanged)
    Q_PROPERTY(QString artist READ artist NOTIFY artistChanged)
    Q_PROPERTY(QString album READ album NOTIFY albumChanged)
    Q_PROPERTY(QString lyrics READ lyrics NOTIFY lyricsChanged)
    Q_PROPERTY(QString currentLyrics READ currentLyrics NOTIFY currentLyricsChanged)
    Q_PROPERTY(QString nextLyrics READ nextLyrics NOTIFY nextLyricsChanged)
    Q_PROPERTY(QString cover READ cover NOTIFY coverChanged)
    Q_PROPERTY(double audioLevel READ audioLevel NOTIFY audioLevelChanged)
    Q_PROPERTY(int globalMouseX READ globalMouseX NOTIFY globalMouseXChanged)
    Q_PROPERTY(int globalMouseY READ globalMouseY NOTIFY globalMouseYChanged)
    Q_PROPERTY(QString backgroundImage READ backgroundImage NOTIFY backgroundImageChanged)
    Q_PROPERTY(QString musicFolder READ musicFolder NOTIFY musicFolderChanged)
    Q_PROPERTY(int playMode READ playMode NOTIFY playModeChanged)
    Q_PROPERTY(QVariantList spectrum READ spectrum NOTIFY spectrumChanged)
    Q_PROPERTY(double volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(bool isMuted READ isMuted WRITE setMuted NOTIFY isMutedChanged)

public:
    explicit PlayerBackend(PlaylistModel *playlist, QObject *parent = nullptr);

    int currentIndex() const { return m_index; }
    bool isPlaying() const;
    qint64 position() const;
    qint64 duration() const;
    QString title() const { return m_title; }
    QString artist() const { return m_artist; }
    QString album() const { return m_album; }
    QString lyrics() const { return m_lyrics; }
    QString currentLyrics() const { return m_currentLyrics; }
    QString nextLyrics() const { return m_nextLyrics; }
    QString cover() const { return m_cover; }
    double audioLevel() const { return m_audioLevel; }
    int globalMouseX() const { return m_globalMouseX; }
    int globalMouseY() const { return m_globalMouseY; }
    QString backgroundImage() const { return m_backgroundImage; }
    QString musicFolder() const { return m_musicFolder; }
    int playMode() const { return m_playMode; }
    QVariantList spectrum() const;
    double volume() const;
    bool isMuted() const;

public slots:
    void play();
    void pause();
    void togglePlay();
    void next();
    void previous();
    void setPosition(qint64 ms);
    void playIndex(int idx);
    void importFolder(const QString &folderPath);
    void updateGlobalMousePosition();
    void setBackgroundImage(const QString &imagePath);
    void resetBackgroundImage();
    void setMusicFolder(const QString &folderPath);
    void saveSettings();
    void loadSettings();
    void delayedInit();
    void setPlayMode(int mode);
    void togglePlayMode();
    void setVolume(double volume);
    void setMuted(bool muted);
    void toggleMute();

signals:
    void currentIndexChanged(int);
    void isPlayingChanged(bool);
    void positionChanged(qint64);
    void durationChanged(qint64);
    void titleChanged();
    void artistChanged();
    void albumChanged();
    void lyricsChanged();
    void currentLyricsChanged();
    void nextLyricsChanged();
    void coverChanged();
    void audioLevelChanged();
    void globalMouseXChanged();
    void globalMouseYChanged();
    void backgroundImageChanged();
    void musicFolderChanged();
    void musicFolderNeeded();
    void playModeChanged();
    void spectrumChanged();
    void volumeChanged();
    void isMutedChanged();
    void escapeKeyPressed();

protected:
    bool eventFilter(QObject *obj, QEvent *event) override;

private slots:
    void onPositionChanged(qint64 pos);
    void onDurationChanged(qint64 dur);
    void onPlaybackStateChanged(QMediaPlayer::PlaybackState st);
    void onMediaStatusChanged(QMediaPlayer::MediaStatus st);
    void updateAudioLevel();
    void updateSpectrum();
    void updateLyrics(qint64 position);
    QStringList parseLyrics(const QString &lyricsText);

private:
    PlaylistModel *m_playlist;
    QMediaPlayer *m_player;
    QAudioOutput *m_audioOutput;
    QTimer *m_audioLevelTimer;

    int m_index = -1;
    QString m_title;
    QString m_artist;
    QString m_album;
    QString m_lyrics;
    QString m_currentLyrics;
    QString m_nextLyrics;
    QString m_cover;
    double m_audioLevel = 0.0;
    QStringList m_parsedLyrics;
    qint64 m_lastLyricPosition = -1;
    int m_globalMouseX = 0;
    int m_globalMouseY = 0;
    QString m_backgroundImage;
    QString m_musicFolder;
    int m_playMode; // 0: Sequential, 1: Loop One, 2: Loop All, 3: Random
    
    // 频谱相关成员
    QVector<double> m_spectrum;   // 例如 30 个频段
    QTimer *m_fftTimer = nullptr;
    
    // 音量相关成员
    double m_volume = 1.0;
    bool m_isMuted = false;
};

#endif // PLAYERBACKEND_H