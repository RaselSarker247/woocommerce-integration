CREATE OR REPLACE PACKAGE LAM.LAM_WEBSITE_DATA IS
PROCEDURE WEBSITE_INVOICE_POST(
        P_CUSTOMER_ID                  NUMBER DEFAULT NULL,
        P_SHIPPING_CHARGES             NUMBER DEFAULT 0,
        P_TRANS_DATE                   DATE DEFAULT SYSDATE,
        P_VAT                          NUMBER DEFAULT 0,
        P_COUPON_CODE                  VARCHAR2 DEFAULT NULL,
        P_COUPON_DISCOUNT              NUMBER DEFAULT 0,
        P_DELIVARY_METHOD              VARCHAR2 DEFAULT NULL,
        P_DELIVARY_DAYS                VARCHAR2 DEFAULT NULL,
        P_SUBTOTAL                     NUMBER DEFAULT NULL,
        P_TOTAL                        NUMBER DEFAULT NULL,
        P_ITEM_DATA                    CLOB DEFAULT NULL,
        P_SHIP_TO_DIFFERENT_ADDR       VARCHAR2 DEFAULT 'N',
        P_CONTACT_MAIL                 VARCHAR2 DEFAULT NULL,
        P_BILLING_ADDR                 CLOB DEFAULT NULL,
        P_SHIPPING_ADDR                CLOB DEFAULT NULL,
        P_ORDER_NOTES                  VARCHAR2 DEFAULT NULL,
        P_STATUS                   OUT NUMBER,
        P_RESULT                   OUT VARCHAR2);
PROCEDURE WEBSITE_CUSTOMER_INSERT(
        P_DATA_JSON                IN  CLOB,
        P_STATUS                   OUT NUMBER,
        P_RESULT                   OUT VARCHAR2);
PROCEDURE WEBSITE_CUSTOMER_UPDATE(
        P_DATA_JSON                IN  CLOB,
        P_STATUS                   OUT NUMBER,
        P_RESULT                   OUT VARCHAR2);
PROCEDURE WEBSITE_CUSTOMER_DELETE(
        P_CUSTOMER_ID              IN  NUMBER,
        P_STATUS                   OUT NUMBER,
        P_RESULT                   OUT VARCHAR2);
PROCEDURE WEBSITE_CUSTOMER_DML(
        P_DML_METHOD               IN  VARCHAR2,
        P_DATA_JSON                IN  CLOB,
        P_STATUS                   OUT NUMBER,
        P_RESULT                   OUT VARCHAR2);
PROCEDURE WEBSITE_PRODUCT_DML(
        P_DML_METHOD               IN  VARCHAR2,
        P_DATA_JSON                IN  CLOB,
        P_STATUS                   OUT NUMBER,
        P_RESULT                   OUT VARCHAR2);
PROCEDURE WEBSITE_ORDER_DML(
        P_DML_METHOD               IN  VARCHAR2,
        P_DATA_JSON                IN  CLOB,
        P_STATUS                   OUT NUMBER,
        P_RESULT                   OUT VARCHAR2);
PROCEDURE WEBSITE_GET_ITEMS(
         P_BRAND        IN VARCHAR2,
         P_CATEGORY     IN VARCHAR2,
         p_SKU          IN VARCHAR2,
         P_DATA_JSON OUT SYS_REFCURSOR);
 PROCEDURE WEBSITE_CUSTOMER_GET(
         P_ID       IN WEBSITE_CUSTOMERS.ID%TYPE,
         P_DATA_JSON OUT SYS_REFCURSOR);        
END;
/
