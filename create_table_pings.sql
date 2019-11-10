CREATE TABLE pings
(
  created_at DateTime,
  user_id UInt32,
  recoded_time UInt16,
  place_id UInt16,
  url String
)
ENGINE = MergeTree()
PARTITION BY (toYYYYMM(created_at), user_id)
ORDER BY created_at;
