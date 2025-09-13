--  trigger để tự động cập nhật loan_accounts.status = 'overdue' khi có bản ghi trong repayments trả chậm quá 30 ngày.
CREATE OR ALTER TRIGGER trg_update_loan_status_overdue
ON bank_repayments
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE a
    SET a.status = 'overdue'
    FROM bank_loan_accounts a
    INNER JOIN inserted b ON a.loan_id = b.loan_id
    INNER JOIN loan_schedule c ON c.loan_id = a.loan_id
    WHERE b.is_late = 1
      AND DATEDIFF(DAY, c.due_date, b.repayment_date) > 30
      AND a.status <> 'overdue';
END;
GO

-- Tạo trigger audit: mỗi khi update loan_accounts.status, ghi log vào bảng loan_status_history.
CREATE TABLE bank_loan_status_history (
    history_id INT IDENTITY(1,1) PRIMARY KEY,
    loan_id INT NOT NULL,
    old_status NVARCHAR(20),
    new_status NVARCHAR(20),
    changed_at DATETIME DEFAULT GETDATE(),
    changed_by NVARCHAR(100) NULL 
	);
--
CREATE OR ALTER TRIGGER trg_audit_loan_status
ON bank_loan_accounts
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO bank_loan_status_history (loan_id, old_status, new_status, changed_at)
    SELECT 
        d.loan_id,
        d.status AS old_status,
        i.status AS new_status,
        GETDATE()
    FROM deleted d
    INNER JOIN inserted i ON d.loan_id = i.loan_id
    WHERE d.status <> i.status; 
END;
GO

-- Tạo trigger kiểm tra: 
-- khi insert vào repayments, nếu repayment_amount < expected_amount 
-- trong loan_schedule thì tự động flag is_partial = true.
ALTER TABLE bank_repayments
ADD is_partial BIT DEFAULT 0;
--
ALTER TABLE bank_repayments
ADD schedule_id INT NULL
    CONSTRAINT fk_repayment_schedule FOREIGN KEY (schedule_id) 
    REFERENCES bank_loan_schedule(schedule_id);
--
CREATE OR ALTER TRIGGER trg_flag_partial_repayment
ON bank_repayments
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE a
    SET a.is_partial = 1
    FROM bank_repayments a
    INNER JOIN inserted b ON a.repayment_id = b.repayment_id
    INNER JOIN bank_loan_schedule c ON c.schedule_id = b.schedule_id
    WHERE b.repayment_amount < c.expected_amount;
END;
GO

-- Tạo trigger gửi cảnh báo: khi penalty_amount > 10% loan gốc 
-- → insert vào bảng alerts.
CREATE TABLE bank_alerts (
    alert_id INT IDENTITY(1,1) PRIMARY KEY,
    loan_id INT NOT NULL,
    penalty_id INT NOT NULL,
    alert_message NVARCHAR(500),
    created_at DATETIME DEFAULT GETDATE(),
    CONSTRAINT fk_alert_loan FOREIGN KEY (loan_id) 
		REFERENCES bank_loan_accounts(loan_id),
    CONSTRAINT fk_alert_penalty FOREIGN KEY (penalty_id) 
		REFERENCES bank_penalties(penalty_id)
)
--
CREATE OR ALTER TRIGGER trg_alert_high_penalty
ON bank_penalties
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO bank_alerts (loan_id, penalty_id, alert_message, created_at)
    SELECT 
        i.loan_id,
        i.penalty_id,
        'Penalty exceeds 10% of loan principal. Penalty: ' 
            + CAST(i.penalty_amount AS NVARCHAR(50))
            + ' / Loan principal: ' + CAST(l.loan_amount AS NVARCHAR(50)),
        GETDATE()
    FROM inserted i
    INNER JOIN bank_loan_accounts l ON i.loan_id = l.loan_id
    WHERE i.penalty_amount > (0.1 * l.loan_amount);
END;
GO
