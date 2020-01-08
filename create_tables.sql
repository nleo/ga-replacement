DROP TABLE IF EXISTS pings;

CREATE TABLE pings
(
  CreatedAt DateTime,
  UserId UInt32,
  ReportInterval UInt16,
  RecodedTime UInt16,
  PageTypeId UInt16,
  CourseId UInt32,
  Url String
)
ENGINE = MergeTree()
PARTITION BY (toYYYYMM(CreatedAt), UserId)
ORDER BY (UserId, CreatedAt);

DROP TABLE IF EXISTS visits;

CREATE TABLE visits
(
  CreatedAt DateTime,
  UserId UInt32,
  Url String
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(CreatedAt)
ORDER BY (UserId, CreatedAt);

DROP TABLE IF EXISTS daily_time_spent;

CREATE MATERIALIZED VIEW daily_time_spent
ENGINE = SummingMergeTree
PARTITION BY toYYYYMM(Day) ORDER BY (UserId, Day, PageTypeId, CourseId)
POPULATE
AS SELECT
  toStartOfDay(CreatedAt) AS Day,
  UserId,
  PageTypeId,
  CourseId,
  sum(ReportInterval) AS timeInSeconds
FROM pings
GROUP BY UserId, Day, PageTypeId, CourseId;
