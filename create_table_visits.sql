CREATE TABLE visits
(
  CreatedAt DateTime,
  UserId UInt32,
  Url String
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(CreatedAt)
ORDER BY CreatedAt;
