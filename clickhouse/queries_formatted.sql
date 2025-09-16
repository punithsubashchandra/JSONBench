------------------------------------------------------------------------------------------------------------------------
-- Q1 - Top event types
------------------------------------------------------------------------------------------------------------------------
SELECT
    data.commit.collection AS event,
    count() AS count
FROM bluesky
GROUP BY event
ORDER BY count DESC;

------------------------------------------------------------------------------------------------------------------------
-- Q2 - Top event types together with unique users per event type
------------------------------------------------------------------------------------------------------------------------
SELECT
    data.commit.collection AS event,
    count() AS count,
    uniqExact(data.did) AS users
FROM bluesky
WHERE data.kind = 'commit'
  AND data.commit.operation = 'create'
GROUP BY event
ORDER BY count DESC;

------------------------------------------------------------------------------------------------------------------------
-- Q3 - When do people use BlueSky
------------------------------------------------------------------------------------------------------------------------
SELECT
    data.commit.collection AS event,
    toHour(fromUnixTimestamp64Micro(data.time_us)) as hour_of_day,
    count() AS count
FROM bluesky
WHERE data.kind = 'commit'
  AND data.commit.operation = 'create'
  AND data.commit.collection in ['app.bsky.feed.post', 'app.bsky.feed.repost', 'app.bsky.feed.like']
GROUP BY event, hour_of_day
ORDER BY hour_of_day, event;

------------------------------------------------------------------------------------------------------------------------
-- Q4 - top 3 post veterans
------------------------------------------------------------------------------------------------------------------------
SELECT
    data.did::String as user_id,
    min(fromUnixTimestamp64Micro(data.time_us)) as first_post_ts
FROM bluesky
WHERE data.kind = 'commit'
  AND data.commit.operation = 'create'
  AND data.commit.collection = 'app.bsky.feed.post'
GROUP BY user_id
ORDER BY first_post_ts ASC
LIMIT 3;

------------------------------------------------------------------------------------------------------------------------
-- Q5 - top 3 users with longest activity
------------------------------------------------------------------------------------------------------------------------
SELECT
    data.did::String as user_id,
    date_diff(
        'milliseconds',
        min(fromUnixTimestamp64Micro(data.time_us)),
        max(fromUnixTimestamp64Micro(data.time_us))) AS activity_span
FROM bluesky
WHERE data.kind = 'commit'
  AND data.commit.operation = 'create'
  AND data.commit.collection = 'app.bsky.feed.post'
GROUP BY user_id
ORDER BY activity_span DESC
LIMIT 3;

------------------------------------------------------------------------------------------------------------------------
-- Q6 - Aggregate stats by user with nested fields and type categorization
------------------------------------------------------------------------------------------------------------------------

SELECT 
    data.did AS user_id,
    -- Similar to how cluster version was used as identifier
    MAX(data.kind) AS activity_type,
    -- Conditional SUMs based on collection types (like storage tier categorization)
    SUM(IF(data.commit.collection = 'app.bsky.feed.post', 1, 0)) AS total_posts,
    SUM(IF(data.commit.collection = 'app.bsky.feed.like', 1, 0)) AS total_likes,
    SUM(IF(data.commit.collection = 'app.bsky.feed.repost', 1, 0)) AS total_reposts,
    SUM(IF(data.commit.collection = 'app.bsky.graph.follow', 1, 0)) AS total_follows,
    -- Taking MAX of metadata (similar to hypervisor info)
    MAX(fromUnixTimestamp64Micro(data.time_us)) AS last_activity_time
FROM bluesky
GROUP BY data.did;


------------------------------------------------------------------------------------------------------------------------
-- Q7 - Activity categorization with time-based grouping
------------------------------------------------------------------------------------------------------------------------
SELECT 
    data.did AS user_id,
    toYYYYMM(fromUnixTimestamp64Micro(data.time_us)) AS activity_month,
    -- Conditional sums based on activity types (like storage tier categorization)
    SUM(CASE 
        WHEN data.commit.collection IN ('app.bsky.feed.post', 'app.bsky.feed.repost')
        THEN 1 ELSE 0 END) AS content_creation_actions,
    SUM(CASE 
        WHEN data.commit.collection IN ('app.bsky.feed.like', 'app.bsky.graph.follow')
        THEN 1 ELSE 0 END) AS engagement_actions
FROM bluesky
GROUP BY 
    data.did,
    toYYYYMM(fromUnixTimestamp64Micro(data.time_us));