CREATE TABLE pings
(
  CreatedAt DateTime,
  UserId UInt32,
  RecodedTime UInt16,
  PageTypeId UInt16,
  Url String
)
ENGINE = MergeTree()
PARTITION BY (toYYYYMM(created_at), user_id)
ORDER BY created_at;
