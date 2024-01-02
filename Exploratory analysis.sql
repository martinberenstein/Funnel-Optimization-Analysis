-- How many times was the app downloaded?
SELECT COUNT(*) as total_downloads FROM app_downloads;
-- How many users signed up on the app?
SELECT COUNT(*) as total_signups FROM signups;
-- How many rides were requested through the app?
SELECT COUNT(*) as total_rides_requested FROM ride_requests;
--How many rides were requested and completed through the app?
WITH user_ride_status AS ( SELECT ride_id, MAX( CASE WHEN dropoff_ts IS NOT NULL
THEN 1 ELSE 0 END ) AS rides_completed FROM ride_requests GROUP BY ride_id ) SELECT COUNT(*) AS total_rides_requested, SUM(rides_completed) AS total_rides_completed FROM user_ride_status;
-- How many rides were requested and how many unique users requested a ride?
SELECT COUNT(DISTINCT user_id) AS total_users_ride_requested, COUNT(user_id) total_rides_requested FROM ride_requests;
-- What is the average time of a ride from pick up to drop off?
SELECT AVG(dropoff_ts-pickup_ts) AS avg_ride_time FROM ride_requests;
-- How many rides were accepted by a driver?
WITH driver_status AS ( SELECT ride_id,
MAX( CASE WHEN accept_ts IS NOT NULL THEN 1 ELSE 0 END ) AS driver_accepted FROM ride_requests GROUP BY ride_id ) SELECT SUM(driver_accepted) AS total_rides_accepted FROM driver_status;
-- How many rides did we successfully collect payments and how much was collected?
SELECT COUNT(DISTINCT ride_id) AS rides_collected_payments, SUM(purchase_amount_usd) FROM transactions WHERE charge_status = 'Approved';
-- How many ride requests happened on each platform?
SELECT platform, COUNT(DISTINCT ride_id) AS total_ride_requests FROM ride_requests r LEFT JOIN signups s
ON r.user_id = s.user_id LEFT JOIN app_downloads d ON s.session_id = d.app_download_key GROUP BY platform ;
-- What is the drop-off from users signing up to users requesting a ride?
WITH total_signups AS ( SELECT COUNT(*) AS total_s FROM signups), total_requests AS ( SELECT COUNT(DISTINCT user_id) AS total_r FROM ride_requests) SELECT (total_s - total_r)::float/total_s as drop_off FROM total_signups, total_requests
-- Waiting time distribution (from ride accepted until pickup)
SELECT AVG(pickup_ts - accept_ts) AS avg_waiting_time, MIN(pickup_ts - accept_ts) AS min_waiting_time, MAX(pickup_ts - accept_ts) AS max_waiting_time FROM ride_requests
-- Funnel Analysis
WITH Visits AS ( SELECT
DISTINCT app_download_key AS user_id, platform, age_range, DATE(download_ts) AS Date FROM app_downloads v FULL JOIN signups ON session_id = app_download_key
), Signups AS ( SELECT DISTINCT s.user_id AS user_id, platform, s.age_range, Date FROM signups s LEFT JOIN Visits v ON session_id = v.user_id ), ride_requested AS ( SELECT DISTINCT r.user_id, ride_id, platform, age_range, Date FROM ride_requests r LEFT JOIN Signups s ON r.user_id = s.user_id ), ride_accepted AS ( SELECT DISTINCT CASE WHEN accept_ts IS NOT NULL
THEN r.user_id END AS user_id, CASE WHEN accept_ts IS NOT NULL THEN r.ride_id END AS ride_id, platform, age_range, Date FROM ride_requests r LEFT JOIN Signups s ON r.user_id = s.user_id ), ride_completed AS ( SELECT DISTINCT CASE WHEN dropoff_ts IS NOT NULL THEN r.user_id END AS user_id, CASE WHEN dropoff_ts IS NOT NULL THEN r.ride_id END AS ride_id, platform, age_range, Date FROM ride_requests r LEFT JOIN Signups s ON r.user_id = s.user_id ), Payment AS (
SELECT DISTINCT CASE WHEN charge_status = 'Approved' THEN r.user_id END AS user_id, CASE WHEN charge_status = 'Approved' THEN t.ride_id END AS ride_id, platform, age_range, Date FROM transactions t LEFT JOIN ride_requests r ON t.ride_id = r.ride_id LEFT JOIN Signups s ON r.user_id = s.user_id ), Review AS ( SELECT DISTINCT r.user_id, r.ride_id, platform, age_range, Date FROM reviews r LEFT JOIN Signups s ON r.user_id = s.user_id ), steps AS ( SELECT 'Download' AS step, COUNT(Visits) AS count, null::bigint as ride_count, platform, age_range, Date FROM Visits GROUP BY platform, age_range, Date UNION SELECT 'Sign Up' AS step, COUNT(Signups) AS count, null::bigint as ride_count , platform, age_range, Date FROM Signups GROUP BY platform, age_range, Date UNION
SELECT 'Ride requested' AS step, COUNT(DISTINCT user_id) AS user_count, COUNT(DISTINCT ride_id) AS ride_count , platform, age_range, Date FROM ride_requested GROUP BY platform, age_range, Date UNION SELECT 'Ride accepted' AS step, COUNT(DISTINCT user_id) AS user_count, COUNT(DISTINCT ride_id) AS ride_count , platform, age_range, Date FROM ride_accepted GROUP BY platform, age_range, Date UNION SELECT 'Ride completed' AS step, COUNT(DISTINCT user_id) AS user_count, COUNT(DISTINCT ride_id) AS ride_count , platform, age_range, Date FROM ride_completed GROUP BY platform, age_range, Date UNION SELECT 'Payment' AS step, COUNT(DISTINCT user_id) AS user_count, COUNT(DISTINCT ride_id) AS ride_count , platform, age_range, Date FROM Payment GROUP BY platform, age_range, Date UNION SELECT 'Review' AS step, COUNT(DISTINCT user_id) AS user_count, COUNT(DISTINCT ride_id) AS ride_count , platform, age_range, Date FROM Review GROUP BY platform, age_range, Date ) SELECT step, platform, age_range, Date, count AS user_count, ride_count
--LAG(count, 1) OVER () AS previous_count, --ROUND((1.0 - count::numeric / LAG(count, 1) OVER ()), 2) AS drop_off FROM steps ORDER BY step, platform, age_range,date ASC;
-- How many bad reviews were realted to the drivers? SELECT review FROM reviews WHERE rating = 1 AND review LIKE '%driver%';
-- How many cancellations were before the driver accepted the ride and what was that average waiting time? SELECT COUNT(ride_id), AVG(cancel_ts-request_ts) AS avg_time_until_cancellation FROM ride_requests WHERE cancel_ts IS NOT NULL and accept_ts IS NULL