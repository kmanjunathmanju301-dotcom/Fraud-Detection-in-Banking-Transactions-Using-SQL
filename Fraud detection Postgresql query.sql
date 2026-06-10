------/* Create table */-------------

CREATE TABLE bank_transactions (
    TransactionID VARCHAR(50),
    AccountID VARCHAR(50),
    TransactionAmount NUMERIC(12,2),
    TransactionDate TIMESTAMP,
    TransactionType VARCHAR(50),
    Location VARCHAR(100),
    DeviceID VARCHAR(100),
    IPAddress VARCHAR(100),
    MerchantID VARCHAR(100),
    Channel VARCHAR(50),
    CustomerAge INT,
    CustomerOccupation VARCHAR(100),
    TransactionDuration INT,
    LoginAttempts INT,
    AccountBalance NUMERIC(15,2),
    PreviousTransactionDate TIMESTAMP
);

------------/* Total table */----------
SELECT *
FROM bank_transactions
------------/* Total transaction */------------

SELECT COUNT(*)
FROM bank_transactions;

--------------/* Total Transaction Amount */-------
SELECT SUM(TransactionAmount) AS TotalAmount
FROM bank_transactions;

-------------/* Average Transaction Amount */----------

SELECT AVG(TransactionAmount) AS AverageAmount
FROM bank_transactions;

-----------/* High-value Transaction Amount */--------

SELECT *
FROM bank_transactions
WHERE TransactionAmount > 30000;

-------------/* Excessive Login Attempts */ -----------
SELECT *
FROM bank_transactions
WHERE LoginAttempts > 3;

-- Fraudulent Patterns: Frequent High-Value Transactions/ Duplicate Transactions/ Unusual Withdrawals

-- 1. Frequent High-Value Transactions (Identifying customers making unusually high transactions in a short time.)

WITH high_value_tx AS (
    SELECT
        t1.AccountID,
        t1.TransactionDate,
        t1.TransactionAmount,
        (
            SELECT COUNT(*)
            FROM bank_transactions t2
            WHERE t2.AccountID = t1.AccountID
              AND t2.TransactionDate BETWEEN
                  t1.TransactionDate - INTERVAL '1 hour'
                  AND t1.TransactionDate
        ) AS tx_count,
        (
            SELECT SUM(t2.TransactionAmount)
            FROM bank_transactions t2
            WHERE t2.AccountID = t1.AccountID
              AND t2.TransactionDate BETWEEN
                  t1.TransactionDate - INTERVAL '1 hour'
                  AND t1.TransactionDate
        ) AS total_value
    FROM bank_transactions t1
)
SELECT *
FROM high_value_tx
WHERE tx_count >= 2
  AND total_value > 1000
ORDER BY total_value DESC;

-- 2. Duplicate Transactions (Detecting multiple transactions with the same amount, timestamp, and recipient.)

with duplicatetx as (
    select transactionid, accountid, transactionamount, transactiondate, merchantid,
           count(*) over (partition by accountid, transactionamount, merchantid, transactiondate) as duplicate_count
    from bank_transactions)
select * from duplicatetx where duplicate_count > 1;


-- 3. Unusual Withdrawals (Identifying withdrawals at odd hours or from different locations in a short period.)

WITH oddhourtx AS (
    SELECT
        t1.transactionid,
        t1.accountid,
        t1.transactiondate,
        t1.transactiontype,
        t1.location,
        EXTRACT(HOUR FROM t1.transactiondate) AS tx_hour,
        (
            SELECT COUNT(DISTINCT t2.location)
            FROM bank_transactions t2
            WHERE t2.accountid = t1.accountid
              AND t2.transactiondate >= t1.transactiondate - INTERVAL '24 hours'
              AND t2.transactiondate <= t1.transactiondate
        ) AS location_changes
    FROM bank_transactions t1
)

SELECT *
FROM oddhourtx
WHERE tx_hour < 6
   OR tx_hour > 22
   OR location_changes > 2;
   
             -------/* Fraud_records stored */-----------

SELECT fraud_type, COUNT(*)
FROM flaggedtransactions
GROUP BY fraud_type;  

-- Storing flagged transactions in a separate table.

CREATE TABLE flaggedtransactions AS

WITH highvaluetx AS (
    SELECT
        t1.accountid,
        t1.transactiondate,
        t1.transactionamount,
        (
            SELECT COUNT(*)
            FROM bank_transactions t2
            WHERE t2.accountid = t1.accountid
              AND t2.transactiondate >= t1.transactiondate - INTERVAL '1 hour'
              AND t2.transactiondate <= t1.transactiondate
        ) AS tx_count,
        (
            SELECT SUM(t2.transactionamount)
            FROM bank_transactions t2
            WHERE t2.accountid = t1.accountid
              AND t2.transactiondate >= t1.transactiondate - INTERVAL '1 hour'
              AND t2.transactiondate <= t1.transactiondate
        ) AS total_value
    FROM bank_transactions t1
),

duplicatetx AS (
    SELECT
        transactionid,
        accountid,
        transactionamount,
        transactiondate,
        merchantid,
        COUNT(*) OVER (
            PARTITION BY accountid,
                         transactionamount,
                         merchantid,
                         transactiondate
        ) AS duplicate_count
    FROM bank_transactions
),

oddhourtx AS (
    SELECT
        t1.transactionid,
        t1.accountid,
        t1.transactiondate,
        t1.transactiontype,
        t1.location,
        t1.transactionamount,
        EXTRACT(HOUR FROM t1.transactiondate) AS tx_hour,
        (
            SELECT COUNT(DISTINCT t2.location)
            FROM bank_transactions t2
            WHERE t2.accountid = t1.accountid
              AND t2.transactiondate >= t1.transactiondate - INTERVAL '24 hours'
              AND t2.transactiondate <= t1.transactiondate
        ) AS location_changes
    FROM bank_transactions t1
)

SELECT *
FROM (
    SELECT
        accountid,
        transactiondate,
        transactionamount,
        'high_value' AS fraud_type
    FROM highvaluetx
    WHERE tx_count >= 2
      AND total_value > 1000

    UNION ALL

    SELECT
        accountid,
        transactiondate,
        transactionamount,
        'duplicate' AS fraud_type
    FROM duplicatetx
    WHERE duplicate_count > 1

    UNION ALL

    SELECT
        accountid,
        transactiondate,
        transactionamount,
        'odd_hour' AS fraud_type
    FROM oddhourtx
    WHERE tx_hour < 6
       OR tx_hour > 22
       OR location_changes > 2
) fraud_records;


---------/*flaggedTransaction */---------

SELECT COUNT(*)
FROM flaggedtransactions;

SELECT *
FROM flaggedtransactions
