# README for Fintech Database SQL Code

## Overview
This project sets up a database for storing and analyzing transaction data for a fintech company. The `fintech_db` 
database contains a table `transactions` with various fields related to financial transactions, including fraud 
detection mechanisms. This code also introduces queries to detect suspicious transaction patterns, calculate 
user-based transaction metrics, and create a system for real-time fraud alerts.

## Prerequisites
- A working MySQL/MariaDB database instance.
- Appropriate user privileges to create databases, tables, and perform data manipulation.

## Database Setup

### Create the database:
The script creates a database named `fintech_db`.

```sql
CREATE DATABASE fintech_db;
USE fintech_db;
```

### Create transactions table:
The transactions table stores details about financial transactions, including:

- transaction_id: Unique identifier for each transaction.
- account_id: ID representing the user's account.
- amount: Amount of the transaction.
- transaction_date: Date and time when the transaction occurred.
- merchant: Information about the merchant.
- location: Location where the transaction took place.
- transaction_type: Indicates the type of transaction (e.g., debit, credit).
- is_fraud: Boolean flag indicating whether the transaction was fraudulent.

```sql
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
```

## Key Queries and Features

### Detect Location Changes
Identifies when a user has made a transaction from a different location compared to their previous transaction.

```sql
SELECT account_id, transaction_id, transaction_date, location,
	LAG(location, 1) OVER (PARTITION BY account_id ORDER BY transaction_date) AS previous_location,
	CASE
		WHEN location <> LAG(location, 1) OVER (PARTITION BY account_id ORDER BY transaction_date) THEN 1
		ELSE 0
	END AS location_change_flag
FROM transactions;
```

### Flag Unusual Transaction Amounts
Flags transactions that fall outside a user's typical transaction range using percentile rank.

```sql
SELECT account_id, transaction_id, amount,
	PERCENT_RANK() OVER (PARTITION BY account_id ORDER BY amount DESC) AS amount_rank
FROM transactions;
```

### Average Transaction Amount per User
Calculates the average transaction amount for each user.

```sql
SELECT account_id, AVG(amount) AS avg_transaction_amount
FROM transactions
GROUP BY account_id;
```

### Average Time Between Transactions
Calculates the average time gap between transactions for each user.

```sql
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
```

### Flag Anomalously High Transactions
Flags transactions where the amount exceeds three times the user's average transaction value.

```sql
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
```

### Rapid Transaction Detection
Flags transactions that occur within a very short time window (e.g., within 5 minutes of the previous transaction).

```sql
SELECT account_id, transaction_id, transaction_date,
	CASE
		WHEN TIMESTAMPDIFF(MINUTE, LAG(transaction_date) OVER (PARTITION BY account_id ORDER BY transaction_date), transaction_date) < 5
        THEN 1
        ELSE 0
	END AS rapid_transaction_flag
FROM transactions;
```

## Fraud Alert System
### Create fraud_alerts Table:
A separate table is created to store alerts related to potential fraudulent activities.

```sql
CREATE TABLE fraud_alerts (
	alert_id SERIAL PRIMARY KEY,
    transaction_id VARCHAR(255),
    account_id INT,
    alert_reason VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Insert Alerts for High Transaction Amounts:
This query inserts a record into fraud_alerts when a transaction amount exceeds three times the user's average.

```sql
INSERT INTO fraud_alerts (transaction_id, account_id, alert_reason)
SELECT t.transaction_id, t.account_id, 'High Transaction Amount'
FROM transactions t
JOIN (
	SELECT account_id, AVG(amount) AS avg_transaction_amount
    FROM transactions
    GROUP BY account_id
) b ON t.account_id = b.account_id
WHERE t.amount > b.avg_transaction_amount * 3;
```

### Summary of Flagged Transactions:
This query provides a summary of accounts that have engaged in fraudulent transactions.

```sql
SELECT account_id, COUNT(*) AS fraud_attempts
FROM transactions
WHERE is_fraud = 1
GROUP BY account_id;
```

## Future Enhancements
- Implement more sophisticated anomaly detection models.
- Set up a real-time fraud monitoring system using triggers or stored procedures.
- Automate the insertion of real-time fraud alerts into the fraud_alerts table.

## How to Run
1. Copy and paste the SQL code into your MySQL/MariaDB client.
2. Execute the code step by step to create the database, the table, and run the queries.
3. Customize the alert thresholds and parameters to fit specific business needs.
4. Integrate with front-end dashboards or reporting tools for better visualization of the insights.

## License
This project is licensed under the MIT License.
