CREATE TABLE customer (
    customer_id UUID PRIMARY KEY NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    surname VARCHAR(50) NOT NULL,
    ssn CHAR(12) NOT NULL,
    created_at DATE NOT NULL DEFAULT CURRENT_DATE
)
