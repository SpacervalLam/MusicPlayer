#ifndef PLAYLISTMODEL_H
#define PLAYLISTMODEL_H

#include <QAbstractListModel>
#include <QVector>
#include <QUrl>

struct TrackItem {
    QString name;    // 文件名（作为后备显示）
    QString title;   // 从元数据提取的标题
    QString artist;  // 从元数据提取的艺术家
    QString album;   // 从元数据提取的唱片集
    QString lyrics;  // 从元数据提取的歌词
    QUrl url;
    int duration; // ms
    QString cover; // qrc or file path
};

class PlaylistModel : public QAbstractListModel
{
    Q_OBJECT
public:
    enum Roles {
        IndexRole = Qt::UserRole + 1,
        NameRole,
        TitleRole,
        ArtistRole,
        AlbumRole,
        LyricsRole,
        UrlRole,
        DurationRole,
        CoverRole
    };

    explicit PlaylistModel(QObject *parent = nullptr);

    // QAbstractItemModel interface
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void clear();
    Q_INVOKABLE void loadFolder(const QString &folderPath);
    Q_INVOKABLE QVariantMap get(int idx) const;

private:
    QVector<TrackItem> m_items;

    void addFile(const QString &filePath);
    QPair<QString, QString> parseFileName(const QString &fileName) const;
};

#endif // PLAYLISTMODEL_H