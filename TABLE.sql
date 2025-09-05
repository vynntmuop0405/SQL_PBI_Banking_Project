-- 1. Bảng Khách Hàng
CREATE TABLE customers (
    customer_id INT IDENTITY(1,1) PRIMARY KEY,
    full_name NVARCHAR(200) NOT NULL,
    dob DATE,
    id_card NVARCHAR(20) UNIQUE,
    phone NVARCHAR(20),
    email NVARCHAR(100),
    created_at DATETIME DEFAULT GETDATE()
);
---

-- 2. Bảng Khoản Vay
CREATE TABLE loan_accounts (
    loan_id INT IDENTITY(1,1) PRIMARY KEY,
    customer_id INT NOT NULL,
    loan_type NVARCHAR(50),  -- personal, mortgage, business...
    loan_amount DECIMAL(18,2) NOT NULL,
    interest_rate DECIMAL(5,2) NOT NULL,  -- % per year
    start_date DATE NOT NULL,
    due_date DATE NOT NULL,
    status NVARCHAR(20) DEFAULT 'active', -- active, closed, overdue, prepaid
    CONSTRAINT fk_loan_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- 3. Bảng Lịch Trả Nợ (Schedule)
CREATE TABLE loan_schedule (
    schedule_id INT IDENTITY(1,1) PRIMARY KEY,
    loan_id INT NOT NULL,
    installment_no INT NOT NULL,
    due_date DATE NOT NULL,
    expected_amount DECIMAL(18,2) NOT NULL,
    CONSTRAINT fk_schedule_loan FOREIGN KEY (loan_id) REFERENCES loan_accounts(loan_id)
);

-- 4. Bảng Thanh Toán
CREATE TABLE repayments (
    repayment_id INT IDENTITY(1,1) PRIMARY KEY,
    loan_id INT NOT NULL,
    repayment_date DATE NOT NULL,
    repayment_amount DECIMAL(18,2) NOT NULL,
    is_late BIT DEFAULT 0,
    CONSTRAINT fk_repayment_loan FOREIGN KEY (loan_id) REFERENCES loan_accounts(loan_id)
);

-- 5. Bảng Phạt
CREATE TABLE penalties (
    penalty_id INT IDENTITY(1,1) PRIMARY KEY,
    loan_id INT NOT NULL,
    repayment_id INT NULL,
    penalty_amount DECIMAL(18,2) NOT NULL,
    penalty_type NVARCHAR(50), -- late_fee, prepayment_fee, etc.
    applied_date DATE DEFAULT GETDATE(),
    CONSTRAINT fk_penalty_loan FOREIGN KEY (loan_id) REFERENCES loan_accounts(loan_id),
    CONSTRAINT fk_penalty_repayment FOREIGN KEY (repayment_id) REFERENCES repayments(repayment_id)
);

-- 6. Bảng Giao Dịch
CREATE TABLE transactions (
    transaction_id INT IDENTITY(1,1) PRIMARY KEY,
    loan_id INT NOT NULL,
    transaction_type NVARCHAR(50), -- disbursement, repayment, penalty, interest, adjustment
    amount DECIMAL(18,2) NOT NULL,
    transaction_date DATE DEFAULT GETDATE(),
    CONSTRAINT fk_transaction_loan FOREIGN KEY (loan_id) REFERENCES loan_accounts(loan_id)
);

