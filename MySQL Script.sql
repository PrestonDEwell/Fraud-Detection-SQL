CREATE DATABASE fintech_db;

USE fintech_db;

DROP TABLE IF EXISTS transactions;

CREATE TABLE transactions (
    transaction_id VARCHAR(255) PRIMARY KEY,
    account_id INT,
    amount DECIMAL(10, 2),
    transaction_date DATETIME,
    transaction_time TIME,
    merchant VARCHAR(255),
    location VARCHAR(255),
    transaction_type VARCHAR(10),
    is_fraud BOOLEAN
);

SELECT * FROM transactions LIMIT 10;

-- Detect if a user made a transaction from a different location compared to their previous transaction
SELECT account_id, transaction_id, transaction_date, location,
	LAG(location, 1) OVER (PARTITION BY account_id ORDER BY transaction_date) AS previous_location,
	CASE
		WHEN location <> LAG(location, 1) OVER (PARTITION BY account_id ORDER BY transaction_date) THEN 1
		ELSE 0
	END AS location_change_flag
FROM transactions;

-- Flag transactions that fall outside the normal transaction range for a user or across the dataset
SELECT account_id, transaction_id, amount,
	PERCENT_RANK() OVER (PARTITION BY account_id ORDER BY amount DESC) AS amount_rank
FROM transactions;

-- Calculate Average Transaction Amount per User
SELECT account_id, AVG(amount) AS avg_transaction_amount
FROM transactions
GROUP BY account_id;

-- Calculate the average time gap between transactions for each user.
SELECT account_id, 
	AVG(time_diff) AS avg_time_between_transactions
FROM (
	SELECT account_id,
		TIMESTAMPDIFF(SECOND,
			LAG(transaction_date) OVER (PARTITION BY account_id ORDER BY transaction_date),
            transaction_date) AS time_diff
	FROM transactions
) AS transaction_differences
WHERE time_diff IS NOT NULL -- Exclude the first transaction for each account where no prior transaction exists
GROUP BY account_id;

-- Flag transactions where the amount is significantly higher (3x) than a user’s baseline
WITH avg_amounts AS (
    SELECT account_id, AVG(amount) AS avg_transaction_amount
    FROM transactions
    GROUP BY account_id
)
SELECT t.account_id, t.transaction_id, t.amount, a.avg_transaction_amount,
       CASE
           WHEN t.amount > a.avg_transaction_amount * 3 THEN 1
           ELSE 0
       END AS amount_anomaly_flag
FROM transactions t
JOIN avg_amounts a ON t.account_id = a.account_id;

-- Flag transactions made in much shorter intervals than usual
SELECT account_id, transaction_id, transaction_date,
	CASE
		WHEN TIMESTAMPDIFF(MINUTE, LAG(transaction_date) OVER (PARTITION BY account_id ORDER BY transaction_date), transaction_date) < 5
        THEN 1
        ELSE 0
	END AS rapid_transaction_flag
FROM transactions;

-- Set Up Real-Time Alerts
-- Create alerts table
CREATE TABLE fraud_alerts (
	alert_id SERIAL PRIMARY KEY,
    transaction_id VARCHAR(255),
    account_id INT,
    alert_reason VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert alerts for fraudulent transactions
INSERT INTO fraud_alerts (transaction_id, account_id, alert_reason)
SELECT t.transaction_id, t.account_id, 'High Transaction Amount'
FROM transactions t
JOIN (
	SELECT account_id, AVG(amount) AS avg_transaction_amount
    FROM transactions
    GROUP BY account_id
) b ON t.account_id = b.account_id
WHERE t.amount > b.avg_transaction_amount * 3;

-- Summary of flagged transactions
SELECT account_id, COUNT(*) AS fraud_attempts
FROM transactions
WHERE is_fraud = 1
GROUP BY account_id;