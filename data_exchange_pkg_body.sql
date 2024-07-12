CREATE OR REPLACE PACKAGE BODY LAM.LAM_WEBSITE_DATA
IS
    PROCEDURE WEBSITE_INVOICE_POST (
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
        P_RESULT                   OUT VARCHAR2)
    IS
       -- pragma autonomous_transaction;
        V_INVOICE_NO      VARCHAR2 (30);
        V_MASTER_INV_ID   NUMBER;
        V_MASTER_INV_NO   VARCHAR2 (30);
        V_BRANCH          NUMBER := 0;
        V_USER            NUMBER := 0;
        V_ITEM_ID         NUMBER;
        V_SHIP_TO_DIFFERENT_ADDR VARCHAR2(100):=P_SHIP_TO_DIFFERENT_ADDR;
        V_BILLING_ADDR CLOB:=P_BILLING_ADDR;
        V_SHIPPING_ADDR CLOB:=P_SHIPPING_ADDR;
    BEGIN
   -- V_SHIP_TO_DIFFERENT_ADDR:=P_SHIP_TO_DIFFERENT_ADDR;
        INSERT INTO dummy (id,val1, clob_val, CLOB_VAL2,CLOB_VAL3)
             VALUES (dummy_seq.NEXTVAL,V_SHIP_TO_DIFFERENT_ADDR, P_ITEM_DATA, V_BILLING_ADDR,V_SHIPPING_ADDR);

        BEGIN
              SELECT    'INV-'
                     || V_BRANCH
                     || '-'
                     || V_USER
                     || '-'
                     || LPAD (
                            TO_NUMBER (
                                  NVL (
                                      MAX (
                                          SUBSTR (INVOICE_NO,
                                                  LENGTH (INVOICE_NO) - 6)),
                                      0)
                                + 1),
                            7,
                            0)
                INTO V_INVOICE_NO
                FROM SM_SALE_INVOICE_MASTER
               WHERE INVOICE_NO LIKE
                         '%INV-' || V_BRANCH || '-' || V_USER || '-' || '%'
            GROUP BY INVOICE_NO
            ORDER BY    'INV-'
                     || V_BRANCH
                     || '-'
                     || V_USER
                     || '-'
                     || LPAD (
                            TO_NUMBER (
                                  NVL (
                                      MAX (
                                          SUBSTR (INVOICE_NO,
                                                  LENGTH (INVOICE_NO) - 6)),
                                      0)
                                + 1),
                            7,
                            0) DESC
               FETCH FIRST ROW ONLY;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                V_INVOICE_NO :=
                    'INV-' || V_BRANCH || '-' || V_USER || '-' || '0000001';
        END;

        INSERT INTO SM_SALE_INVOICE_MASTER (INVOICE_ID,
                                            INVOICE_NO,
                                            TRANS_DATE,
                                            CUSTOMER_ID,
                                            DELIVERY_CHARGES,
                                            TOTAL_AMOUNT,
                                            TAX_AMOUNT,
                                            NET_AMOUNT,
                                            CREATION_DATE,
                                            COMPANY_ID,
                                            BRANCH_ID,
                                            WEBSITE_SALES_FLAG,
                                            WEBSITE_ORDER_CONTACT,
                                            WEBSITE_ORDER_NOTES,
                                            WEBSITE_ORDER_COUPON_CODE,
                                            WEBSITE_ORDER_COUPON_DISCOUNT,
                                            WEBSITE_ORDER_SHIPPING_METHOD,
                                            WEBSITE_ORDER_SHIPPING_DAYS)
             VALUES (
                        (SELECT NVL (MAX (INVOICE_ID), 1000000000) + 1
                           FROM SM_SALE_INVOICE_MASTER), --SM_SALE_INVOICE_MASTER_SEQ.NEXTVAL,
                        V_INVOICE_NO,
                        P_TRANS_DATE,
                        P_CUSTOMER_ID,
                        P_SHIPPING_CHARGES,
                        P_SUBTOTAL,
                        P_VAT,
                        P_TOTAL,
                        SYSDATE,
                        1,
                        2,
                        1,
                        P_CONTACT_MAIL,
                        P_ORDER_NOTES,
                        P_COUPON_CODE,
                        P_COUPON_DISCOUNT,
                        P_DELIVARY_METHOD,
                        P_DELIVARY_DAYS)
          RETURNING INVOICE_ID, INVOICE_NO
               INTO V_MASTER_INV_ID, V_MASTER_INV_NO;

        FOR i
            IN (SELECT *
                  FROM JSON_TABLE (
                           P_ITEM_DATA,
                           '$.items[*]'
                           COLUMNS (
                               SKU VARCHAR2 (100) PATH '$.SKU',
                               QTY NUMBER PATH '$.QTY',
                               RATE NUMBER PATH '$.RATE',
                               ITEM_GIFT
                                   NUMBER
                                   PATH '$.ITEM_GIFT',
                               TOTAL_VALUE NUMBER PATH '$.TOTAL_VALUE')))
        LOOP

            SELECT ITEM_ID
              INTO V_ITEM_ID
              FROM STR_SETUP_ITEM_DTL
             WHERE SKU = I.SKU;

            INSERT INTO SM_SALE_INVOICE_DETAIL (INVOICE_DETAIL_ID,
                                                INVOICE_ID,
                                                ITEM_ID,
                                                QTY,
                                                RATE,
                                                AMOUNT,
                                                DISCOUNT_AMOUNT,
                                                TOTAL_VALUE,
                                                CREATION_DATE)
                 VALUES (SM_SALE_INVOICE_DETAIL_SEQ.NEXTVAL,              --PK
                         V_MASTER_INV_ID,
                         V_ITEM_ID,
                         I.QTY,                                   -- SCALE_ID,
                         I.RATE,
                         I.QTY * I.RATE,
                         I.ITEM_GIFT *I.QTY,
                         (I.QTY * I.RATE) - (I.ITEM_GIFT*I.QTY),
                         SYSDATE);
        END LOOP;


        IF V_SHIP_TO_DIFFERENT_ADDR = 'N'
        THEN
            FOR B
                IN (SELECT *
                      FROM JSON_TABLE (
                               V_BILLING_ADDR,
                               '$.billing[*]'
                               COLUMNS (
                                   FIRST_NAME
                                       VARCHAR2 (1000)
                                       PATH '$.FIRST_NAME',
                                   LAST_NAME
                                       VARCHAR2 (1000)
                                       PATH '$.LAST_NAME',
                                   STREET_ADDRESS
                                       VARCHAR2 (1000)
                                       PATH '$.STREET_ADDRESS',
                                   APARTMENT
                                       VARCHAR2 (1000)
                                       PATH '$.APARTMENT',
                                   TOWN_CITY
                                       VARCHAR2 (1000)
                                       PATH '$.TOWN_CITY',
                                   COUNTRY_REGION
                                       VARCHAR2 (1000)
                                       PATH '$.COUNTRY_REGION',
                                   STATE_COUNTY
                                       VARCHAR2 (1000)
                                       PATH '$.STATE_COUNTY',
                                   POSTCODE_ZIP
                                       VARCHAR2 (1000)
                                       PATH '$.POSTCODE_ZIP')))
            LOOP
                INSERT INTO WEBSITE_CUSTOMER_ADDRESS (ID,
                                                      ADDRESS_TYPE,
                                                      CUSTOMER_ID,
                                                      INVOICE_NO,
                                                      FIRST_NAME,
                                                      Last_name,
                                                      STREET_ADDRESS,
                                                      Apartment,
                                                      Town_City,
                                                      Country_Region,
                                                      State_County,
                                                      Postcode_ZIP)
                     VALUES (WEBSITE_CUSTOMER_ADDRESS_SEQ.NEXTVAL,
                             'B',
                             P_CUSTOMER_ID,
                             V_MASTER_INV_NO,
                             B.FIRST_NAME,
                             B.LAST_NAME,
                             B.STREET_ADDRESS,
                             B.APARTMENT,
                             B.TOWN_CITY,
                             B.COUNTRY_REGION,
                             B.STATE_COUNTY,
                             B.POSTCODE_ZIP);
                INSERT INTO WEBSITE_CUSTOMER_ADDRESS (ID,
                                                      ADDRESS_TYPE,
                                                      CUSTOMER_ID,
                                                      INVOICE_NO,
                                                      FIRST_NAME,
                                                      Last_name,
                                                      STREET_ADDRESS,
                                                      Apartment,
                                                      Town_City,
                                                      Country_Region,
                                                      State_County,
                                                      Postcode_ZIP)
                     VALUES (WEBSITE_CUSTOMER_ADDRESS_SEQ.NEXTVAL,
                             'S',
                             P_CUSTOMER_ID,
                             V_MASTER_INV_NO,
                             B.FIRST_NAME,
                             B.LAST_NAME,
                             B.STREET_ADDRESS,
                             B.APARTMENT,
                             B.TOWN_CITY,
                             B.COUNTRY_REGION,
                             B.STATE_COUNTY,
                             B.POSTCODE_ZIP);

            END LOOP;
            ELSIF V_SHIP_TO_DIFFERENT_ADDR = 'Y' THEN
                   INSERT INTO dummy (id,val1, clob_val, CLOB_VAL2,CLOB_VAL3)
             VALUES (dummy_seq.NEXTVAL,'Get Y', P_ITEM_DATA, V_BILLING_ADDR,V_SHIPPING_ADDR);
                        FOR I
                IN (SELECT *
                      FROM JSON_TABLE (
                               V_BILLING_ADDR,
                               '$.billing[*]'
                               COLUMNS (
                                   FIRST_NAME
                                       VARCHAR2 (1000)
                                       PATH '$.FIRST_NAME',
                                   LAST_NAME
                                       VARCHAR2 (1000)
                                       PATH '$.LAST_NAME',
                                   STREET_ADDRESS
                                       VARCHAR2 (1000)
                                       PATH '$.STREET_ADDRESS',
                                   APARTMENT
                                       VARCHAR2 (1000)
                                       PATH '$.APARTMENT',
                                   TOWN_CITY
                                       VARCHAR2 (1000)
                                       PATH '$.TOWN_CITY',
                                   COUNTRY_REGION
                                       VARCHAR2 (1000)
                                       PATH '$.COUNTRY_REGION',
                                   STATE_COUNTY
                                       VARCHAR2 (1000)
                                       PATH '$.STATE_COUNTY',
                                   POSTCODE_ZIP
                                       VARCHAR2 (1000)
                                       PATH '$.POSTCODE_ZIP')))
            LOOP
                INSERT INTO WEBSITE_CUSTOMER_ADDRESS (ID,
                                                      ADDRESS_TYPE,
                                                      CUSTOMER_ID,
                                                      INVOICE_NO,
                                                      FIRST_NAME,
                                                      Last_name,
                                                      STREET_ADDRESS,
                                                      Apartment,
                                                      Town_City,
                                                      Country_Region,
                                                      State_County,
                                                      Postcode_ZIP)
                     VALUES (WEBSITE_CUSTOMER_ADDRESS_SEQ.NEXTVAL,
                             'B',
                             P_CUSTOMER_ID,
                             V_MASTER_INV_NO,
                             I.FIRST_NAME,
                             I.LAST_NAME,
                             I.STREET_ADDRESS,
                             I.APARTMENT,
                             I.TOWN_CITY,
                             I.COUNTRY_REGION,
                             I.STATE_COUNTY,
                             I.POSTCODE_ZIP);
  

            END LOOP;
                                    FOR I
                IN (SELECT *
                      FROM JSON_TABLE (
                               V_SHIPPING_ADDR,
                               '$.shipping[*]'
                               COLUMNS (
                                   FIRST_NAME
                                       VARCHAR2 (1000)
                                       PATH '$.FIRST_NAME',
                                   LAST_NAME
                                       VARCHAR2 (1000)
                                       PATH '$.LAST_NAME',
                                   STREET_ADDRESS
                                       VARCHAR2 (1000)
                                       PATH '$.STREET_ADDRESS',
                                   APARTMENT
                                       VARCHAR2 (1000)
                                       PATH '$.APARTMENT',
                                   TOWN_CITY
                                       VARCHAR2 (1000)
                                       PATH '$.TOWN_CITY',
                                   COUNTRY_REGION
                                       VARCHAR2 (1000)
                                       PATH '$.COUNTRY_REGION',
                                   STATE_COUNTY
                                       VARCHAR2 (1000)
                                       PATH '$.STATE_COUNTY',
                                   POSTCODE_ZIP
                                       VARCHAR2 (1000)
                                       PATH '$.POSTCODE_ZIP')))
            LOOP
                INSERT INTO WEBSITE_CUSTOMER_ADDRESS (ID,
                                                      ADDRESS_TYPE,
                                                      CUSTOMER_ID,
                                                      INVOICE_NO,
                                                      FIRST_NAME,
                                                      Last_name,
                                                      STREET_ADDRESS,
                                                      Apartment,
                                                      Town_City,
                                                      Country_Region,
                                                      State_County,
                                                      Postcode_ZIP)
                     VALUES (WEBSITE_CUSTOMER_ADDRESS_SEQ.NEXTVAL,
                             'S',
                             P_CUSTOMER_ID,
                             V_MASTER_INV_NO,
                             I.FIRST_NAME,
                             I.LAST_NAME,
                             I.STREET_ADDRESS,
                             I.APARTMENT,
                             I.TOWN_CITY,
                             I.COUNTRY_REGION,
                             I.STATE_COUNTY,
                             I.POSTCODE_ZIP);
                END LOOP;
        END IF;

        P_STATUS := 201;
        P_RESULT := V_MASTER_INV_NO;
    EXCEPTION
        WHEN OTHERS
        THEN
            P_STATUS := 400;
            P_RESULT := SQLERRM;

   END;
PROCEDURE WEBSITE_CUSTOMER_INSERT(
        P_DATA_JSON                IN  CLOB,
        P_STATUS                   OUT NUMBER,
        P_RESULT                   OUT VARCHAR2) IS
BEGIN
        INSERT INTO dummy (id,clob_val)
             VALUES (dummy_seq.NEXTVAL,P_DATA_JSON);
FOR I IN (SELECT
  jt.id,
  jt.date_created,
  jt.date_created_gmt,
  jt.date_modified,
  jt.date_modified_gmt,
  jt.email,
  jt.first_name,
  jt.last_name,
  jt.role,
  jt.username,
  jt.billing_first_name,
  jt.billing_last_name,
  jt.billing_company,
  jt.billing_address_1,
  jt.billing_address_2,
  jt.billing_city,
  jt.billing_state,
  jt.billing_postcode,
  jt.billing_country,
  jt.billing_email,
  jt.billing_phone,
  jt.shipping_first_name,
  jt.shipping_last_name,
  jt.shipping_company,
  jt.shipping_address_1,
  jt.shipping_address_2,
  jt.shipping_city,
  jt.shipping_state,
  jt.shipping_postcode,
  jt.shipping_country,
  jt.is_paying_customer,
  jt.avatar_url,
  jt.self_href,
  jt.collection_href
FROM
  JSON_TABLE(
    P_DATA_JSON,
    '$'
    COLUMNS (
      id NUMBER PATH '$.id',
      date_created DATE PATH '$.date_created',
      date_created_gmt DATE PATH '$.date_created_gmt',
      date_modified DATE PATH '$.date_modified',
      date_modified_gmt DATE PATH '$.date_modified_gmt',
      email VARCHAR2(255 CHAR) PATH '$.email',
      first_name VARCHAR2(255) PATH '$.first_name',
      last_name VARCHAR2(255) PATH '$.last_name',
      role VARCHAR2(50 CHAR) PATH '$.role',
      username VARCHAR2(255) PATH '$.username',
      billing_first_name VARCHAR2(255) PATH '$.billing.first_name',
      billing_last_name VARCHAR2(255) PATH '$.billing.last_name',
      billing_company VARCHAR2(255) PATH '$.billing.company',
      billing_address_1 VARCHAR2(255) PATH '$.billing.address_1',
      billing_address_2 VARCHAR2(255) PATH '$.billing.address_2',
      billing_city VARCHAR2(255) PATH '$.billing.city',
      billing_state VARCHAR2(50 CHAR) PATH '$.billing.state',
      billing_postcode VARCHAR2(20 CHAR) PATH '$.billing.postcode',
      billing_country VARCHAR2(50 CHAR) PATH '$.billing.country',
      billing_email VARCHAR2(255 CHAR) PATH '$.billing.email',
      billing_phone VARCHAR2(20 CHAR) PATH '$.billing.phone',
      shipping_first_name VARCHAR2(255) PATH '$.shipping.first_name',
      shipping_last_name VARCHAR2(255) PATH '$.shipping.last_name',
      shipping_company VARCHAR2(255) PATH '$.shipping.company',
      shipping_address_1 VARCHAR2(255) PATH '$.shipping.address_1',
      shipping_address_2 VARCHAR2(255) PATH '$.shipping.address_2',
      shipping_city VARCHAR2(255) PATH '$.shipping.city',
      shipping_state VARCHAR2(50 CHAR) PATH '$.shipping.state',
      shipping_postcode VARCHAR2(20 CHAR) PATH '$.shipping.postcode',
      shipping_country VARCHAR2(50 CHAR) PATH '$.shipping.country',
      is_paying_customer NUMBER PATH '$.is_paying_customer',
      avatar_url VARCHAR2(255) PATH '$.avatar_url',
      self_href VARCHAR2(255) PATH '$._links.self[0].href',
      collection_href VARCHAR2(255) PATH '$._links.collection[0].href'
    )
  ) jt) LOOP
      INSERT INTO WEBSITE_CUSTOMERS
      (
       ID
      ,DATE_CREATED
      ,DATE_CREATED_GMT
      ,DATE_MODIFIED
      ,DATE_MODIFIED_GMT
      ,EMAIL
      ,FIRST_NAME
      ,LAST_NAME
      ,ROLE
      ,USERNAME
      ,IS_PAYING_CUSTOMER
      ,AVATAR_URL
      )
    VALUES
      (
       i.ID
      ,i.DATE_CREATED
      ,i.DATE_CREATED_GMT
      ,i.DATE_MODIFIED
      ,i.DATE_MODIFIED_GMT
      ,i.EMAIL
      ,i.FIRST_NAME
      ,i.LAST_NAME
      ,i.ROLE
      ,i.USERNAME
      ,i.IS_PAYING_CUSTOMER
      ,i.AVATAR_URL
      );
          INSERT INTO WEBSITE_SHIPPING_ADDRESS
      (
       ID
      ,INVOICE_NO
      ,CUSTOMER_ID
      ,FIRST_NAME
      ,LAST_NAME
      ,COMPANY
      ,ADDRESS_1
      ,ADDRESS_2
      ,CITY
      ,STATE
      ,POSTCODE
      ,COUNTRY
      )
    VALUES
      (
       WEBSITE_SHIPPING_ADDRESS_SEQ.NEXTVAL
      ,null
      ,i.ID  --Customer_id
      ,i.shipping_FIRST_NAME
      ,i.shipping_LAST_NAME
      ,i.shipping_COMPANY
      ,i.shipping_ADDRESS_1
      ,i.shipping_ADDRESS_2
      ,i.shipping_CITY
      ,i.shipping_STATE
      ,i.shipping_POSTCODE
      ,i.shipping_COUNTRY
      );
                INSERT INTO  WEBSITE_BILLING_ADDRESS
      (
       ID
      ,INVOICE_NO
      ,CUSTOMER_ID
      ,FIRST_NAME
      ,LAST_NAME
      ,COMPANY
      ,ADDRESS_1
      ,ADDRESS_2
      ,CITY
      ,STATE
      ,POSTCODE
      ,COUNTRY
      ,EMAIL
      ,PHONE
      )
    VALUES
      (
       WEBSITE_BILLING_ADDRESS_SEQ.NEXTVAL
      ,null
      ,i.ID  --Customer_id
      ,i.billing_FIRST_NAME
      ,i.billing_LAST_NAME
      ,i.billing_COMPANY
      ,i.billing_ADDRESS_1
      ,i.billing_ADDRESS_2
      ,i.billing_CITY
      ,i.billing_STATE
      ,i.billing_POSTCODE
      ,i.billing_COUNTRY
      ,i.billing_EMAIL
      ,i.billing_PHONE
      );
      
      END LOOP;
      
        P_STATUS := 201;
        P_RESULT :='Created Succsessfully';
    EXCEPTION
        WHEN OTHERS
        THEN
            P_STATUS := 400;
            P_RESULT := SQLERRM;
 END;
PROCEDURE WEBSITE_CUSTOMER_UPDATE(
        P_DATA_JSON                IN  CLOB,
        P_STATUS                   OUT NUMBER,
        P_RESULT                   OUT VARCHAR2) IS
BEGIN
        INSERT INTO dummy (id,clob_val)
             VALUES (dummy_seq.NEXTVAL,P_DATA_JSON);
FOR I IN (SELECT
  jt.id,
  jt.date_created,
  jt.date_created_gmt,
  jt.date_modified,
  jt.date_modified_gmt,
  jt.email,
  jt.first_name,
  jt.last_name,
  jt.role,
  jt.username,
  jt.billing_first_name,
  jt.billing_last_name,
  jt.billing_company,
  jt.billing_address_1,
  jt.billing_address_2,
  jt.billing_city,
  jt.billing_state,
  jt.billing_postcode,
  jt.billing_country,
  jt.billing_email,
  jt.billing_phone,
  jt.shipping_first_name,
  jt.shipping_last_name,
  jt.shipping_company,
  jt.shipping_address_1,
  jt.shipping_address_2,
  jt.shipping_city,
  jt.shipping_state,
  jt.shipping_postcode,
  jt.shipping_country,
  jt.is_paying_customer,
  jt.avatar_url,
  jt.self_href,
  jt.collection_href
FROM
  JSON_TABLE(
    P_DATA_JSON,
    '$'
    COLUMNS (
      id NUMBER PATH '$.id',
      date_created DATE PATH '$.date_created',
      date_created_gmt DATE PATH '$.date_created_gmt',
      date_modified DATE PATH '$.date_modified',
      date_modified_gmt DATE PATH '$.date_modified_gmt',
      email VARCHAR2(255 CHAR) PATH '$.email',
      first_name VARCHAR2(255) PATH '$.first_name',
      last_name VARCHAR2(255) PATH '$.last_name',
      role VARCHAR2(50 CHAR) PATH '$.role',
      username VARCHAR2(255) PATH '$.username',
      billing_first_name VARCHAR2(255) PATH '$.billing.first_name',
      billing_last_name VARCHAR2(255) PATH '$.billing.last_name',
      billing_company VARCHAR2(255) PATH '$.billing.company',
      billing_address_1 VARCHAR2(255) PATH '$.billing.address_1',
      billing_address_2 VARCHAR2(255) PATH '$.billing.address_2',
      billing_city VARCHAR2(255) PATH '$.billing.city',
      billing_state VARCHAR2(50 CHAR) PATH '$.billing.state',
      billing_postcode VARCHAR2(20 CHAR) PATH '$.billing.postcode',
      billing_country VARCHAR2(50 CHAR) PATH '$.billing.country',
      billing_email VARCHAR2(255 CHAR) PATH '$.billing.email',
      billing_phone VARCHAR2(20 CHAR) PATH '$.billing.phone',
      shipping_first_name VARCHAR2(255) PATH '$.shipping.first_name',
      shipping_last_name VARCHAR2(255) PATH '$.shipping.last_name',
      shipping_company VARCHAR2(255) PATH '$.shipping.company',
      shipping_address_1 VARCHAR2(255) PATH '$.shipping.address_1',
      shipping_address_2 VARCHAR2(255) PATH '$.shipping.address_2',
      shipping_city VARCHAR2(255) PATH '$.shipping.city',
      shipping_state VARCHAR2(50 CHAR) PATH '$.shipping.state',
      shipping_postcode VARCHAR2(20 CHAR) PATH '$.shipping.postcode',
      shipping_country VARCHAR2(50 CHAR) PATH '$.shipping.country',
      is_paying_customer NUMBER PATH '$.is_paying_customer',
      avatar_url VARCHAR2(255) PATH '$.avatar_url',
      self_href VARCHAR2(255) PATH '$._links.self[0].href',
      collection_href VARCHAR2(255) PATH '$._links.collection[0].href'
    )
  ) jt) LOOP
      UPDATE WEBSITE_CUSTOMERS
      SET
      DATE_MODIFIED=I.DATE_MODIFIED
      ,EMAIL=i.EMAIL
      ,FIRST_NAME=i.FIRST_NAME
      ,LAST_NAME=i.LAST_NAME
      ,ROLE=i.ROLE
      ,USERNAME=i.USERNAME
      ,IS_PAYING_CUSTOMER=i.IS_PAYING_CUSTOMER
      ,AVATAR_URL=i.AVATAR_URL
     WHERE ID= I.ID;

          UPDATE WEBSITE_SHIPPING_ADDRESS
      SET 
      FIRST_NAME=i.shipping_FIRST_NAME
      ,LAST_NAME=i.shipping_LAST_NAME
      ,COMPANY=i.shipping_COMPANY
      ,ADDRESS_1=i.shipping_ADDRESS_1
      ,ADDRESS_2=i.shipping_ADDRESS_2
      ,CITY=i.shipping_CITY
      ,STATE=i.shipping_STATE
      ,POSTCODE=i.shipping_POSTCODE
      ,COUNTRY=i.shipping_COUNTRY
      WHERE CUSTOMER_ID= I.ID AND INVOICE_NO IS NULL;
    UPDATE WEBSITE_BILLING_ADDRESS
      SET
      FIRST_NAME=i.billing_FIRST_NAME
      ,LAST_NAME=i.billing_LAST_NAME
      ,COMPANY=i.billing_COMPANY
      ,ADDRESS_1=i.billing_ADDRESS_1
      ,ADDRESS_2=i.billing_ADDRESS_2
      ,CITY=i.billing_CITY
      ,STATE=i.billing_STATE
      ,POSTCODE=i.billing_POSTCODE
      ,COUNTRY=i.billing_COUNTRY
      ,EMAIL=i.billing_EMAIL
      ,PHONE=i.billing_PHONE
      WHERE CUSTOMER_ID= I.ID AND INVOICE_NO IS NULL;
      
      END LOOP;
      
        P_STATUS := 200;
        P_RESULT :='Updated Succsessfully';
    EXCEPTION
        WHEN OTHERS
        THEN
            P_STATUS := 400;
            P_RESULT := SQLERRM;
 END;
 PROCEDURE WEBSITE_CUSTOMER_DELETE(
        P_CUSTOMER_ID              IN  NUMBER,
        P_STATUS                   OUT NUMBER,
        P_RESULT                   OUT VARCHAR2) is
BEGIN

  DELETE WEBSITE_SHIPPING_ADDRESS WHERE CUSTOMER_ID= P_CUSTOMER_ID AND INVOICE_NO  IS NULL;
  DELETE WEBSITE_BILLING_ADDRESS WHERE CUSTOMER_ID= P_CUSTOMER_ID AND INVOICE_NO  IS NULL;
  DELETE WEBSITE_CUSTOMERS WHERE ID= P_CUSTOMER_ID;
        P_STATUS := 200;
        P_RESULT :='Deleted Succsessfully';
    EXCEPTION
        WHEN OTHERS
        THEN
            P_STATUS := 400;
            P_RESULT := SQLERRM;
 END; 
 
 
 
 
 
 
 
 
 
 
 PROCEDURE WEBSITE_CUSTOMER_DML(
        P_DML_METHOD               IN  VARCHAR2,
        P_DATA_JSON                IN  CLOB,
        P_STATUS                   OUT NUMBER,
        P_RESULT                   OUT VARCHAR2) IS
V_REFERENCE_NO NUMBER;
V_CUSTOMER_RETURN WEBSITE_CUSTOMERS.ID%TYPE;
BEGIN

IF P_DML_METHOD=UPPER('INSERT') THEN 
BEGIN
        INSERT INTO dummy (id,val1,val2,clob_val)
             VALUES (dummy_seq.NEXTVAL,'INSERT','CUSTOMER',P_DATA_JSON);
FOR I IN (SELECT
  jt.id,
  jt.date_created,
  jt.date_created_gmt,
  jt.date_modified,
  jt.date_modified_gmt,
  jt.email,
  jt.first_name,
  jt.last_name,
  jt.role,
  jt.username,
  jt.billing_first_name,
  jt.billing_last_name,
  jt.billing_company,
  jt.billing_address_1,
  jt.billing_address_2,
  jt.billing_city,
  jt.billing_state,
  jt.billing_postcode,
  jt.billing_country,
  jt.billing_email,
  jt.billing_phone,
  jt.shipping_first_name,
  jt.shipping_last_name,
  jt.shipping_company,
  jt.shipping_address_1,
  jt.shipping_address_2,
  jt.shipping_city,
  jt.shipping_state,
  jt.shipping_postcode,
  jt.shipping_country,
  jt.is_paying_customer,
  jt.avatar_url,
  jt.self_href,
  jt.collection_href
FROM
  JSON_TABLE(
    P_DATA_JSON,
    '$'
    COLUMNS (
      id NUMBER PATH '$.id',
      date_created DATE PATH '$.date_created',
      date_created_gmt DATE PATH '$.date_created_gmt',
      date_modified DATE PATH '$.date_modified',
      date_modified_gmt DATE PATH '$.date_modified_gmt',
      email VARCHAR2(255 CHAR) PATH '$.email',
      first_name VARCHAR2(255) PATH '$.first_name',
      last_name VARCHAR2(255) PATH '$.last_name',
      role VARCHAR2(50 CHAR) PATH '$.role',
      username VARCHAR2(255) PATH '$.username',
      billing_first_name VARCHAR2(255) PATH '$.billing.first_name',
      billing_last_name VARCHAR2(255) PATH '$.billing.last_name',
      billing_company VARCHAR2(255) PATH '$.billing.company',
      billing_address_1 VARCHAR2(255) PATH '$.billing.address_1',
      billing_address_2 VARCHAR2(255) PATH '$.billing.address_2',
      billing_city VARCHAR2(255) PATH '$.billing.city',
      billing_state VARCHAR2(50 CHAR) PATH '$.billing.state',
      billing_postcode VARCHAR2(20 CHAR) PATH '$.billing.postcode',
      billing_country VARCHAR2(50 CHAR) PATH '$.billing.country',
      billing_email VARCHAR2(255 CHAR) PATH '$.billing.email',
      billing_phone VARCHAR2(20 CHAR) PATH '$.billing.phone',
      shipping_first_name VARCHAR2(255) PATH '$.shipping.first_name',
      shipping_last_name VARCHAR2(255) PATH '$.shipping.last_name',
      shipping_company VARCHAR2(255) PATH '$.shipping.company',
      shipping_address_1 VARCHAR2(255) PATH '$.shipping.address_1',
      shipping_address_2 VARCHAR2(255) PATH '$.shipping.address_2',
      shipping_city VARCHAR2(255) PATH '$.shipping.city',
      shipping_state VARCHAR2(50 CHAR) PATH '$.shipping.state',
      shipping_postcode VARCHAR2(20 CHAR) PATH '$.shipping.postcode',
      shipping_country VARCHAR2(50 CHAR) PATH '$.shipping.country',
      is_paying_customer NUMBER PATH '$.is_paying_customer',
      avatar_url VARCHAR2(255) PATH '$.avatar_url',
      self_href VARCHAR2(255) PATH '$._links.self[0].href',
      collection_href VARCHAR2(255) PATH '$._links.collection[0].href'
    )
  ) jt) LOOP
      INSERT INTO WEBSITE_CUSTOMERS
      (
       ID
      ,DATE_CREATED
      ,DATE_CREATED_GMT
      ,DATE_MODIFIED
      ,DATE_MODIFIED_GMT
      ,EMAIL
      ,FIRST_NAME
      ,LAST_NAME
      ,ROLE
      ,USERNAME
      ,IS_PAYING_CUSTOMER
      ,AVATAR_URL
      )
    VALUES
      (
       i.ID
      ,i.DATE_CREATED
      ,i.DATE_CREATED_GMT
      ,i.DATE_MODIFIED
      ,i.DATE_MODIFIED_GMT
      ,i.EMAIL
      ,i.FIRST_NAME
      ,i.LAST_NAME
      ,i.ROLE
      ,i.USERNAME
      ,i.IS_PAYING_CUSTOMER
      ,i.AVATAR_URL
      ) RETURNING ID INTO V_CUSTOMER_RETURN;
      
          INSERT INTO WEBSITE_SHIPPING_ADDRESS
      (
       ID
      ,INVOICE_NO
      ,CUSTOMER_ID
      ,FIRST_NAME
      ,LAST_NAME
      ,COMPANY
      ,ADDRESS_1
      ,ADDRESS_2
      ,CITY
      ,STATE
      ,POSTCODE
      ,COUNTRY
      )
    VALUES
      (
       WEBSITE_SHIPPING_ADDRESS_SEQ.NEXTVAL
      ,null
      ,i.ID  --Customer_id
      ,i.shipping_FIRST_NAME
      ,i.shipping_LAST_NAME
      ,i.shipping_COMPANY
      ,i.shipping_ADDRESS_1
      ,i.shipping_ADDRESS_2
      ,i.shipping_CITY
      ,i.shipping_STATE
      ,i.shipping_POSTCODE
      ,i.shipping_COUNTRY
      );
                INSERT INTO  WEBSITE_BILLING_ADDRESS
      (
       ID
      ,INVOICE_NO
      ,CUSTOMER_ID
      ,FIRST_NAME
      ,LAST_NAME
      ,COMPANY
      ,ADDRESS_1
      ,ADDRESS_2
      ,CITY
      ,STATE
      ,POSTCODE
      ,COUNTRY
      ,EMAIL
      ,PHONE
      )
    VALUES
      (
       WEBSITE_BILLING_ADDRESS_SEQ.NEXTVAL
      ,null
      ,i.ID  --Customer_id
      ,i.billing_FIRST_NAME
      ,i.billing_LAST_NAME
      ,i.billing_COMPANY
      ,i.billing_ADDRESS_1
      ,i.billing_ADDRESS_2
      ,i.billing_CITY
      ,i.billing_STATE
      ,i.billing_POSTCODE
      ,i.billing_COUNTRY
      ,i.billing_EMAIL
      ,i.billing_PHONE
      );
      
      END LOOP;

            
            
                    IF V_CUSTOMER_RETURN IS NOT NULL THEN
       UPDATE WEBSITE_CUSTOMERS SET CUSTOMER_JSON =P_DATA_JSON WHERE ID=V_CUSTOMER_RETURN;
        P_STATUS := 201;
        P_RESULT :='Customer ID '||V_CUSTOMER_RETURN||' Created Succsessfully';
        ELSE 
        V_REFERENCE_NO:=TO_NUMBER(TO_CHAR(SYSTIMESTAMP,'YYYYMMDDHH24MISSFF3'));
                    INSERT INTO dummy (id,val1,val2,clob_val,REFERENCE_NO)
             VALUES (dummy_seq.NEXTVAL,'INSERT','CUSTOMER',P_DATA_JSON,V_REFERENCE_NO);
        P_STATUS := 400;
        P_RESULT :='Something wrong, Contact your developer with error code - '||V_REFERENCE_NO;
        END IF;
        
    EXCEPTION
        WHEN OTHERS
        THEN
            P_STATUS := 400;
            P_RESULT := SQLERRM;
            IF P_RESULT='ORA-00001: unique constraint (LAM.WEBSITE_CUSTOMERS_PK) violated' THEN
            P_RESULT:= 'Customer ID already available';
            END IF;
            
            
            
END;
ELSIF P_DML_METHOD=UPPER('UPDATE') THEN
BEGIN
        INSERT INTO dummy (id,val1,val2,clob_val)
             VALUES (dummy_seq.NEXTVAL,'UPDATE','CUSTOMER',P_DATA_JSON);
FOR I IN (SELECT
  jt.id,
  jt.date_created,
  jt.date_created_gmt,
  jt.date_modified,
  jt.date_modified_gmt,
  jt.email,
  jt.first_name,
  jt.last_name,
  jt.role,
  jt.username,
  jt.billing_first_name,
  jt.billing_last_name,
  jt.billing_company,
  jt.billing_address_1,
  jt.billing_address_2,
  jt.billing_city,
  jt.billing_state,
  jt.billing_postcode,
  jt.billing_country,
  jt.billing_email,
  jt.billing_phone,
  jt.shipping_first_name,
  jt.shipping_last_name,
  jt.shipping_company,
  jt.shipping_address_1,
  jt.shipping_address_2,
  jt.shipping_city,
  jt.shipping_state,
  jt.shipping_postcode,
  jt.shipping_country,
  jt.is_paying_customer,
  jt.avatar_url,
  jt.self_href,
  jt.collection_href
FROM
  JSON_TABLE(
    P_DATA_JSON,
    '$'
    COLUMNS (
      id NUMBER PATH '$.id',
      date_created DATE PATH '$.date_created',
      date_created_gmt DATE PATH '$.date_created_gmt',
      date_modified DATE PATH '$.date_modified',
      date_modified_gmt DATE PATH '$.date_modified_gmt',
      email VARCHAR2(255 CHAR) PATH '$.email',
      first_name VARCHAR2(255) PATH '$.first_name',
      last_name VARCHAR2(255) PATH '$.last_name',
      role VARCHAR2(50 CHAR) PATH '$.role',
      username VARCHAR2(255) PATH '$.username',
      billing_first_name VARCHAR2(255) PATH '$.billing.first_name',
      billing_last_name VARCHAR2(255) PATH '$.billing.last_name',
      billing_company VARCHAR2(255) PATH '$.billing.company',
      billing_address_1 VARCHAR2(255) PATH '$.billing.address_1',
      billing_address_2 VARCHAR2(255) PATH '$.billing.address_2',
      billing_city VARCHAR2(255) PATH '$.billing.city',
      billing_state VARCHAR2(50 CHAR) PATH '$.billing.state',
      billing_postcode VARCHAR2(20 CHAR) PATH '$.billing.postcode',
      billing_country VARCHAR2(50 CHAR) PATH '$.billing.country',
      billing_email VARCHAR2(255 CHAR) PATH '$.billing.email',
      billing_phone VARCHAR2(20 CHAR) PATH '$.billing.phone',
      shipping_first_name VARCHAR2(255) PATH '$.shipping.first_name',
      shipping_last_name VARCHAR2(255) PATH '$.shipping.last_name',
      shipping_company VARCHAR2(255) PATH '$.shipping.company',
      shipping_address_1 VARCHAR2(255) PATH '$.shipping.address_1',
      shipping_address_2 VARCHAR2(255) PATH '$.shipping.address_2',
      shipping_city VARCHAR2(255) PATH '$.shipping.city',
      shipping_state VARCHAR2(50 CHAR) PATH '$.shipping.state',
      shipping_postcode VARCHAR2(20 CHAR) PATH '$.shipping.postcode',
      shipping_country VARCHAR2(50 CHAR) PATH '$.shipping.country',
      is_paying_customer NUMBER PATH '$.is_paying_customer',
      avatar_url VARCHAR2(255) PATH '$.avatar_url',
      self_href VARCHAR2(255) PATH '$._links.self[0].href',
      collection_href VARCHAR2(255) PATH '$._links.collection[0].href'
    )
  ) jt) LOOP
      UPDATE WEBSITE_CUSTOMERS
      SET
      DATE_MODIFIED=I.DATE_MODIFIED
      ,EMAIL=i.EMAIL
      ,FIRST_NAME=i.FIRST_NAME
      ,LAST_NAME=i.LAST_NAME
      ,ROLE=i.ROLE
      ,USERNAME=i.USERNAME
      ,IS_PAYING_CUSTOMER=i.IS_PAYING_CUSTOMER
      ,AVATAR_URL=i.AVATAR_URL
     WHERE ID= I.ID RETURNING ID INTO V_CUSTOMER_RETURN;

          UPDATE WEBSITE_SHIPPING_ADDRESS
      SET 
      FIRST_NAME=i.shipping_FIRST_NAME
      ,LAST_NAME=i.shipping_LAST_NAME
      ,COMPANY=i.shipping_COMPANY
      ,ADDRESS_1=i.shipping_ADDRESS_1
      ,ADDRESS_2=i.shipping_ADDRESS_2
      ,CITY=i.shipping_CITY
      ,STATE=i.shipping_STATE
      ,POSTCODE=i.shipping_POSTCODE
      ,COUNTRY=i.shipping_COUNTRY
      WHERE CUSTOMER_ID= I.ID AND INVOICE_NO IS NULL;
    UPDATE WEBSITE_BILLING_ADDRESS
      SET
      FIRST_NAME=i.billing_FIRST_NAME
      ,LAST_NAME=i.billing_LAST_NAME
      ,COMPANY=i.billing_COMPANY
      ,ADDRESS_1=i.billing_ADDRESS_1
      ,ADDRESS_2=i.billing_ADDRESS_2
      ,CITY=i.billing_CITY
      ,STATE=i.billing_STATE
      ,POSTCODE=i.billing_POSTCODE
      ,COUNTRY=i.billing_COUNTRY
      ,EMAIL=i.billing_EMAIL
      ,PHONE=i.billing_PHONE
      WHERE CUSTOMER_ID= I.ID AND INVOICE_NO IS NULL;
      
      END LOOP;
      
            
                    IF V_CUSTOMER_RETURN IS NOT NULL THEN
        UPDATE WEBSITE_CUSTOMERS SET CUSTOMER_JSON =P_DATA_JSON WHERE ID=V_CUSTOMER_RETURN;
        P_STATUS := 200;
        P_RESULT :='Customer ID '||V_CUSTOMER_RETURN||' Updated Succsessfully';
        ELSE 
        V_REFERENCE_NO:=TO_NUMBER(TO_CHAR(SYSTIMESTAMP,'YYYYMMDDHH24MISSFF3'));
                    INSERT INTO dummy (id,val1,val2,clob_val,REFERENCE_NO)
             VALUES (dummy_seq.NEXTVAL,'UPDATE','CUSTOMER',P_DATA_JSON,V_REFERENCE_NO);
        P_STATUS := 400;
        P_RESULT :='Something wrong, Contact your developer with error code - '||V_REFERENCE_NO;
        END IF;
        
    EXCEPTION
        WHEN OTHERS
        THEN
            P_STATUS := 400;
            P_RESULT := SQLERRM;

            
            
            
END;
ELSIF P_DML_METHOD=UPPER('DELETE') THEN
BEGIN
        INSERT INTO dummy (id,val1,val2,clob_val)
             VALUES (dummy_seq.NEXTVAL,'DELETE','CUSTOMER',P_DATA_JSON);
FOR I IN(
SELECT 
  jt.*
FROM
  JSON_TABLE(
    P_DATA_JSON,
    '$'
    COLUMNS (
      customer_id NUMBER PATH '$.id'))jt) loop


  DELETE WEBSITE_SHIPPING_ADDRESS WHERE CUSTOMER_ID= I.customer_id AND INVOICE_NO  IS NULL;
  DELETE WEBSITE_BILLING_ADDRESS WHERE CUSTOMER_ID= I.customer_id AND INVOICE_NO  IS NULL;
  DELETE WEBSITE_CUSTOMERS WHERE ID= I.customer_id RETURNING ID INTO V_CUSTOMER_RETURN;
  END LOOP;

                    IF V_CUSTOMER_RETURN IS NOT NULL THEN
        P_STATUS := 200;
        P_RESULT :='Customer ID '||V_CUSTOMER_RETURN||' Deleted Succsessfully';
        ELSE 
        V_REFERENCE_NO:=TO_NUMBER(TO_CHAR(SYSTIMESTAMP,'YYYYMMDDHH24MISSFF3'));
                    INSERT INTO dummy (id,val1,val2,clob_val,REFERENCE_NO)
             VALUES (dummy_seq.NEXTVAL,'DELETE','CUSTOMER',P_DATA_JSON,V_REFERENCE_NO);
        P_STATUS := 400;
        P_RESULT :='Something wrong, Contact your developer with error code - '||V_REFERENCE_NO;
        END IF;
        
    EXCEPTION
        WHEN OTHERS
        THEN
            P_STATUS := 400;
            P_RESULT := SQLERRM;

            
END;
END IF;







END;
PROCEDURE WEBSITE_PRODUCT_DML(
        P_DML_METHOD               IN  VARCHAR2,
        P_DATA_JSON                IN  CLOB,
        P_STATUS                   OUT NUMBER,
        P_RESULT                   OUT VARCHAR2) IS
V_PRODUCT_ID NUMBER;
V_IAMGE_ID NUMBER;
V_CATEGORY_ID NUMBER;
V_PRODUCT_RETURN WEBSITE_PRODUCTS.ID%TYPE;
V_REFERENCE_NO NUMBER;
BEGIN
        INSERT INTO dummy (id,val1,val2,clob_val)
             VALUES (dummy_seq.NEXTVAL,P_DML_METHOD,'PRODUCT',P_DATA_JSON);
FOR I IN (
SELECT
  jt.id,
  jt.name,
  jt.slug,
  jt.permalink,
  jt.date_created,
  jt.date_created_gmt,
  jt.date_modified,
  jt.date_modified_gmt,
  jt.type,
  jt.status,
  jt.featured,
  jt.catalog_visibility,
  jt.description,
  jt.short_description,
  jt.sku,
  jt.price,
  jt.regular_price,
  jt.sale_price,
  jt.date_on_sale_from,
  jt.date_on_sale_from_gmt,
  jt.date_on_sale_to,
  jt.date_on_sale_to_gmt,
  jt.price_html,
  jt.on_sale,
  jt.purchasable,
  jt.total_sales,
  jt.virtual,
  jt.downloadable,
  jt.download_limit,
  jt.download_expiry,
  jt.external_url,
  jt.button_text,
  jt.tax_status,
  jt.tax_class,
  jt.manage_stock,
  jt.stock_quantity,
  jt.stock_status,
  jt.backorders,
  jt.backorders_allowed,
  jt.backordered,
  jt.sold_individually,
  jt.weight,
  jt.length,
  jt.width,
  jt.height,
  jt.shipping_required,
  jt.shipping_taxable,
  jt.shipping_class,
  jt.shipping_class_id,
  jt.reviews_allowed,
  jt.average_rating,
  jt.rating_count,
  jt.related_id,
  jt.upsell_id,
  jt.cross_sell_id,
  jt.parent_id,
  jt.purchase_note,
  jt.category_id,
  jt.category_name,
  jt.category_slug,
  jt.tag,
  jt.image_id,
  jt.image_src,
  jt.image_name,
  jt.image_alt,
  jt.attribute_name,
  jt.attribute_value,
  jt.default_attribute_name,
  jt.default_attribute_value,
  jt.variation_id,
  jt.grouped_product_id,
  jt.menu_order,
  jt.meta_key,
  jt.meta_value,
  jt.self_href,
  jt.collection_href
FROM
  JSON_TABLE(
    P_DATA_JSON,
    '$'
    COLUMNS (
      id NUMBER PATH '$.id',
      name VARCHAR2 PATH '$.name',
      slug VARCHAR2 PATH '$.slug',
      permalink VARCHAR2 PATH '$.permalink',
      date_created TIMESTAMP PATH '$.date_created',
      date_created_gmt TIMESTAMP PATH '$.date_created_gmt',
      date_modified TIMESTAMP PATH '$.date_modified',
      date_modified_gmt TIMESTAMP PATH '$.date_modified_gmt',
      type VARCHAR2 PATH '$.type',
      status VARCHAR2 PATH '$.status',
      featured NUMBER PATH '$.featured',
      catalog_visibility VARCHAR2 PATH '$.catalog_visibility',
      description CLOB PATH '$.description',
      short_description VARCHAR2 PATH '$.short_description',
      sku VARCHAR2 PATH '$.sku',
      price VARCHAR2 PATH '$.price',
      regular_price VARCHAR2 PATH '$.regular_price',
      sale_price VARCHAR2 PATH '$.sale_price',
      date_on_sale_from TIMESTAMP PATH '$.date_on_sale_from',
      date_on_sale_from_gmt TIMESTAMP PATH '$.date_on_sale_from_gmt',
      date_on_sale_to TIMESTAMP PATH '$.date_on_sale_to',
      date_on_sale_to_gmt TIMESTAMP PATH '$.date_on_sale_to_gmt',
      price_html VARCHAR2 PATH '$.price_html',
      on_sale NUMBER PATH '$.on_sale',
      purchasable NUMBER PATH '$.purchasable',
      total_sales NUMBER PATH '$.total_sales',
      virtual NUMBER PATH '$.virtual',
      downloadable NUMBER PATH '$.downloadable',
      download_limit NUMBER PATH '$.download_limit',
      download_expiry NUMBER PATH '$.download_expiry',
      external_url VARCHAR2 PATH '$.external_url',
      button_text VARCHAR2 PATH '$.button_text',
      tax_status VARCHAR2 PATH '$.tax_status',
      tax_class VARCHAR2 PATH '$.tax_class',
      manage_stock NUMBER PATH '$.manage_stock',
      stock_quantity NUMBER PATH '$.stock_quantity',
      stock_status VARCHAR2 PATH '$.stock_status',
      backorders VARCHAR2 PATH '$.backorders',
      backorders_allowed NUMBER PATH '$.backorders_allowed',
      backordered NUMBER PATH '$.backordered',
      sold_individually NUMBER PATH '$.sold_individually',
      weight VARCHAR2 PATH '$.weight',
      length VARCHAR2 PATH '$.dimensions.length',
      width VARCHAR2 PATH '$.dimensions.width',
      height VARCHAR2 PATH '$.dimensions.height',
      shipping_required NUMBER PATH '$.shipping_required',
      shipping_taxable NUMBER PATH '$.shipping_taxable',
      shipping_class VARCHAR2 PATH '$.shipping_class',
      shipping_class_id NUMBER PATH '$.shipping_class_id',
      reviews_allowed NUMBER PATH '$.reviews_allowed',
      average_rating VARCHAR2 PATH '$.average_rating',
      rating_count NUMBER PATH '$.rating_count',
      NESTED PATH '$.related_ids[*]' COLUMNS (related_id NUMBER PATH '$'),
      NESTED PATH '$.upsell_ids[*]' COLUMNS (upsell_id NUMBER PATH '$'),
      NESTED PATH '$.cross_sell_ids[*]' COLUMNS (cross_sell_id NUMBER PATH '$'),
      parent_id NUMBER PATH '$.parent_id',
      purchase_note VARCHAR2 PATH '$.purchase_note',
      NESTED PATH '$.categories[*]' COLUMNS (category_id NUMBER PATH '$.id', category_name VARCHAR2 PATH '$.name', category_slug VARCHAR2 PATH '$.slug'),
      NESTED PATH '$.tags[*]' COLUMNS (tag VARCHAR2 PATH '$'),
      NESTED PATH '$.images[*]' COLUMNS (image_id NUMBER PATH '$.id', image_src VARCHAR2 PATH '$.src',image_name VARCHAR2 PATH '$.name', image_alt VARCHAR2 PATH '$.alt'),
      NESTED PATH '$.attributes[*]' COLUMNS (attribute_name VARCHAR2 PATH '$.name', attribute_value VARCHAR2 PATH '$.value'),
      NESTED PATH '$.default_attributes[*]' COLUMNS (default_attribute_name VARCHAR2 PATH '$.name', default_attribute_value VARCHAR2 PATH '$.value'),
      NESTED PATH '$.variations[*]' COLUMNS (variation_id NUMBER PATH '$.id'),
      NESTED PATH '$.grouped_products[*]' COLUMNS (grouped_product_id NUMBER PATH '$'),
      menu_order NUMBER PATH '$.menu_order',
      NESTED PATH '$.meta_data[*]' COLUMNS (meta_key VARCHAR2 PATH '$.key', meta_value VARCHAR2 PATH '$.value'),
      NESTED PATH '$._links' COLUMNS (self_href VARCHAR2 PATH '$.self[0].href', collection_href VARCHAR2 PATH '$.collection[0].href')
    )
  ) jt) LOOP


IF P_DML_METHOD=UPPER('INSERT') THEN 

BEGIN

 if NVL(V_CATEGORY_ID,I.category_id-1) != I.category_id THEN    --FOR NOT MATCH WITH ID
INSERT INTO website_product_categories(id,name,slug)
values(I.category_id,I.category_name,I.category_slug);
V_CATEGORY_ID:=I.category_id;
END IF;
IF NVL(V_PRODUCT_ID,I.ID-1) != I.ID  THEN  --FOR NOT MATCH WITH ID
    INSERT INTO WEBSITE_PRODUCTS
      (
       ID
      ,NAME
      ,SLUG
      ,PERMALINK
      ,DATE_CREATED
      ,DATE_CREATED_GMT
      ,DATE_MODIFIED
      ,DATE_MODIFIED_GMT
      ,TYPE
      ,STATUS
      ,FEATURED
      ,CATALOG_VISIBILITY
      ,DESCRIPTION
      ,SHORT_DESCRIPTION
      ,SKU
      ,PRICE
      ,REGULAR_PRICE
      ,SALE_PRICE
      ,DATE_ON_SALE_FROM
      ,DATE_ON_SALE_FROM_GMT
      ,DATE_ON_SALE_TO
      ,DATE_ON_SALE_TO_GMT
      ,PRICE_HTML
      ,ON_SALE
      ,PURCHASABLE
      ,TOTAL_SALES
      ,VIRTUAL
      ,DOWNLOADABLE
      ,DOWNLOAD_LIMIT
      ,DOWNLOAD_EXPIRY
      ,EXTERNAL_URL
      ,BUTTON_TEXT
      ,TAX_STATUS
      ,TAX_CLASS
      ,MANAGE_STOCK
      ,STOCK_QUANTITY
      ,STOCK_STATUS
      ,BACKORDERS
      ,BACKORDERS_ALLOWED
      ,BACKORDERED
      ,SOLD_INDIVIDUALLY
      ,WEIGHT
      ,SHIPPING_REQUIRED
      ,SHIPPING_TAXABLE
      ,SHIPPING_CLASS
      ,SHIPPING_CLASS_ID
      ,REVIEWS_ALLOWED
      ,AVERAGE_RATING
      ,RATING_COUNT
      ,PARENT_ID
      ,PURCHASE_NOTE
      ,MENU_ORDER
      ,CATEGORY_ID
      )
    VALUES
      (
       i.ID
      ,i.NAME
      ,i.SLUG
      ,i.PERMALINK
      ,i.DATE_CREATED
      ,i.DATE_CREATED_GMT
      ,i.DATE_MODIFIED
      ,i.DATE_MODIFIED_GMT
      ,i.TYPE
      ,i.STATUS
      ,i.FEATURED
      ,i.CATALOG_VISIBILITY
      ,i.DESCRIPTION
      ,i.SHORT_DESCRIPTION
      ,i.SKU
      ,i.PRICE
      ,i.REGULAR_PRICE
      ,i.SALE_PRICE
      ,i.DATE_ON_SALE_FROM
      ,i.DATE_ON_SALE_FROM_GMT
      ,i.DATE_ON_SALE_TO
      ,i.DATE_ON_SALE_TO_GMT
      ,i.PRICE_HTML
      ,i.ON_SALE
      ,i.PURCHASABLE
      ,i.TOTAL_SALES
      ,i.VIRTUAL
      ,i.DOWNLOADABLE
      ,i.DOWNLOAD_LIMIT
      ,i.DOWNLOAD_EXPIRY
      ,i.EXTERNAL_URL
      ,i.BUTTON_TEXT
      ,i.TAX_STATUS
      ,i.TAX_CLASS
      ,i.MANAGE_STOCK
      ,i.STOCK_QUANTITY
      ,i.STOCK_STATUS
      ,i.BACKORDERS
      ,i.BACKORDERS_ALLOWED
      ,i.BACKORDERED
      ,i.SOLD_INDIVIDUALLY
      ,i.WEIGHT
      ,i.SHIPPING_REQUIRED
      ,i.SHIPPING_TAXABLE
      ,i.SHIPPING_CLASS
      ,i.SHIPPING_CLASS_ID
      ,i.REVIEWS_ALLOWED
      ,i.AVERAGE_RATING
      ,i.RATING_COUNT
      ,i.PARENT_ID
      ,i.PURCHASE_NOTE
      ,i.MENU_ORDER
      ,I.category_id
      ) RETURNING ID INTO V_PRODUCT_RETURN;
  V_PRODUCT_ID:= I.ID;

END IF;
--IF NVL(V_IAMGE_ID,I.image_id-1) != I.image_id THEN  --FOR NOT MATCH WITH ID
IF V_IAMGE_ID != I.image_id THEN
    INSERT INTO WEBSITE_PRODUCT_IMAGES
      (
       ID
      ,PRODUCT_ID
      ,DATE_CREATED
      ,DATE_CREATED_GMT
      ,DATE_MODIFIED
      ,DATE_MODIFIED_GMT
      ,SRC
      ,NAME
      ,ALT
      )
    VALUES
      (
       i.image_id
      ,i.ID--PRODUCT_ID
      ,i.DATE_CREATED
      ,i.DATE_CREATED_GMT
      ,i.DATE_MODIFIED
      ,i.DATE_MODIFIED_GMT
      ,i.image_src
      ,i.image_name
      ,i.image_alt
      );
      V_IAMGE_ID:= I.image_id;
      END IF;

      
        IF V_PRODUCT_RETURN IS NOT NULL THEN
        UPDATE WEBSITE_PRODUCTS SET PRODUCT_JSON=P_DATA_JSON WHERE ID=V_PRODUCT_RETURN;
        P_STATUS := 201;
        P_RESULT :='Product ID '||V_PRODUCT_RETURN||' Created Succsessfully';
        ELSE 
        V_REFERENCE_NO:=TO_NUMBER(TO_CHAR(SYSTIMESTAMP,'YYYYMMDDHH24MISSFF3'));
                    INSERT INTO dummy (id,val1,val2,clob_val,REFERENCE_NO)
             VALUES (dummy_seq.NEXTVAL,'INSERT','PRODUCT',P_DATA_JSON,V_REFERENCE_NO);
        P_STATUS := 400;
        P_RESULT :='Something wrong, Contact your developer with error code - '||V_REFERENCE_NO;
        END IF;
        
    EXCEPTION
        WHEN OTHERS
        THEN
            P_STATUS := 400;
            P_RESULT := SQLERRM;
            IF P_RESULT='ORA-00001: unique constraint (LAM.WEBSITE_PRODUCTS_PK) violated' THEN
            P_RESULT:= 'Product ID already available';
            END IF;
END;
ELSIF P_DML_METHOD=UPPER('UPDATE') THEN
BEGIN
        INSERT INTO dummy (id,val1,val2,clob_val)
             VALUES (dummy_seq.NEXTVAL,'UPDATE','CUSTOMER',P_DATA_JSON);
             
 if NVL(V_CATEGORY_ID,I.category_id-1) != I.category_id THEN    --FOR NOT MATCH WITH ID
UPDATE website_product_categories SET name=I.category_name,slug=I.category_slug WHERE ID=I.category_id;
V_CATEGORY_ID:=I.category_id;
END IF;


IF NVL(V_PRODUCT_ID,I.ID-1) != I.ID  THEN  --FOR NOT MATCH WITH ID
    UPDATE  WEBSITE_PRODUCTS SET
       NAME=i.NAME
      ,SLUG=i.SLUG
      ,PERMALINK=i.PERMALINK
      ,DATE_MODIFIED=i.DATE_MODIFIED
      ,DATE_MODIFIED_GMT=i.DATE_MODIFIED_GMT
      ,TYPE=i.TYPE
      ,STATUS=i.STATUS
      ,FEATURED=i.FEATURED
      ,CATALOG_VISIBILITY=i.CATALOG_VISIBILITY
      ,DESCRIPTION=i.DESCRIPTION
      ,SHORT_DESCRIPTION=i.SHORT_DESCRIPTION
      ,SKU=i.SKU
      ,PRICE=i.PRICE
      ,REGULAR_PRICE=i.REGULAR_PRICE
      ,SALE_PRICE=i.SALE_PRICE
      ,DATE_ON_SALE_FROM=i.DATE_ON_SALE_FROM
      ,DATE_ON_SALE_FROM_GMT=i.DATE_ON_SALE_FROM_GMT
      ,DATE_ON_SALE_TO=i.DATE_ON_SALE_TO
      ,DATE_ON_SALE_TO_GMT=i.DATE_ON_SALE_TO_GMT
      ,PRICE_HTML=i.PRICE_HTML
      ,ON_SALE=i.ON_SALE
      ,PURCHASABLE=i.PURCHASABLE
      ,TOTAL_SALES=i.TOTAL_SALES
      ,VIRTUAL=i.VIRTUAL
      ,DOWNLOADABLE=i.DOWNLOADABLE
      ,DOWNLOAD_LIMIT=i.DOWNLOAD_LIMIT
      ,DOWNLOAD_EXPIRY=i.DOWNLOAD_EXPIRY
      ,EXTERNAL_URL=i.EXTERNAL_URL
      ,BUTTON_TEXT=i.BUTTON_TEXT
      ,TAX_STATUS=i.TAX_STATUS
      ,TAX_CLASS=i.TAX_CLASS
      ,MANAGE_STOCK=i.MANAGE_STOCK
      ,STOCK_QUANTITY=i.STOCK_QUANTITY
      ,STOCK_STATUS=i.STOCK_STATUS
      ,BACKORDERS=i.BACKORDERS
      ,BACKORDERS_ALLOWED=i.BACKORDERS_ALLOWED
      ,BACKORDERED=i.BACKORDERED
      ,SOLD_INDIVIDUALLY=i.SOLD_INDIVIDUALLY
      ,WEIGHT=i.WEIGHT
      ,SHIPPING_REQUIRED=i.SHIPPING_REQUIRED
      ,SHIPPING_TAXABLE=i.SHIPPING_TAXABLE
      ,SHIPPING_CLASS=i.SHIPPING_CLASS
      ,SHIPPING_CLASS_ID=i.SHIPPING_CLASS_ID
      ,REVIEWS_ALLOWED=i.REVIEWS_ALLOWED
      ,AVERAGE_RATING=i.AVERAGE_RATING
      ,RATING_COUNT=i.RATING_COUNT
      ,PARENT_ID=i.PARENT_ID
      ,PURCHASE_NOTE=i.PURCHASE_NOTE
      ,MENU_ORDER=i.MENU_ORDER
      ,CATEGORY_ID=I.category_id
      WHERE ID=I.ID RETURNING ID INTO V_PRODUCT_RETURN;
  V_PRODUCT_ID:= I.ID;
END IF;
IF NVL(V_IAMGE_ID,I.image_id-1) != I.image_id THEN  --FOR NOT MATCH WITH ID
    update WEBSITE_PRODUCT_IMAGES set

       PRODUCT_ID=i.ID--PRODUCT_ID
      ,DATE_MODIFIED=i.DATE_MODIFIED
      ,DATE_MODIFIED_GMT=i.DATE_MODIFIED_GMT
      ,SRC=i.image_src
      ,NAME=i.image_name
      ,ALT=i.image_alt
      where id=i.image_id;
      V_IAMGE_ID:= I.image_id;
      END IF;


        IF V_PRODUCT_RETURN IS NOT NULL THEN
        UPDATE WEBSITE_PRODUCTS SET PRODUCT_JSON=P_DATA_JSON WHERE ID=V_PRODUCT_RETURN;
        P_STATUS := 200;
        P_RESULT :='Product ID '||V_PRODUCT_RETURN||' Updated Succsessfully';
        ELSE 
        V_REFERENCE_NO:=TO_NUMBER(TO_CHAR(SYSTIMESTAMP,'YYYYMMDDHH24MISSFF3'));
                    INSERT INTO dummy (id,val1,val2,clob_val,REFERENCE_NO)
             VALUES (dummy_seq.NEXTVAL,'UPDATE','PRODUCT',P_DATA_JSON,V_REFERENCE_NO);
        P_STATUS := 400;
        P_RESULT :='Something wrong, Contact your developer with error code - '||V_REFERENCE_NO;
        END IF;
        
    EXCEPTION
        WHEN OTHERS
        THEN
            P_STATUS := 400;
            P_RESULT := SQLERRM;


END;
ELSIF P_DML_METHOD=UPPER('DELETE') THEN
BEGIN
        INSERT INTO dummy (id,val1,val2,clob_val)
             VALUES (dummy_seq.NEXTVAL,'DELETE','CUSTOMER',P_DATA_JSON);
FOR I IN(
SELECT 
  jt.*
FROM
  JSON_TABLE(
    P_DATA_JSON,
    '$'
    COLUMNS (
      product_id NUMBER PATH '$.id'))jt) loop


  DELETE WEBSITE_PRODUCT_IMAGES WHERE product_id= I.product_id;
  DELETE WEBSITE_PRODUCTS WHERE ID= I.product_id RETURNING ID INTO V_PRODUCT_RETURN;

  END LOOP;
        IF V_PRODUCT_RETURN IS NOT NULL THEN
        P_STATUS := 200;
        P_RESULT :='Product ID '||V_PRODUCT_RETURN||' Deleted Succsessfully';
        ELSE 
        V_REFERENCE_NO:=TO_NUMBER(TO_CHAR(SYSTIMESTAMP,'YYYYMMDDHH24MISSFF3'));
                    INSERT INTO dummy (id,val1,val2,clob_val,REFERENCE_NO)
             VALUES (dummy_seq.NEXTVAL,'DELETE','PRODUCT',P_DATA_JSON,V_REFERENCE_NO);
        P_STATUS := 400;
        P_RESULT :='Something wrong, Contact your developer with error code - '||V_REFERENCE_NO;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            P_STATUS := 400;
            P_RESULT := SQLERRM;
END;
END IF;
END LOOP;
END;      
PROCEDURE WEBSITE_ORDER_DML(
        P_DML_METHOD               IN  VARCHAR2,
        P_DATA_JSON                IN  CLOB,
        P_STATUS                   OUT NUMBER,
        P_RESULT                   OUT VARCHAR2) IS
V_ORDER_ID NUMBER;
V_PRODUCT_ID NUMBER;
V_SHIPPING VARCHAR2(1000);
V_BILLING  VARCHAR2(1000);
V_SHIPPING_METHOD VARCHAR2(1000);
V_ORDER_RETURN WEBSITE_ORDERS.ID%TYPE;
V_REFERENCE_NO NUMBER;
 BEGIN
     IF P_DML_METHOD=UPPER('INSERT') THEN 
            INSERT INTO dummy (id,val1,val2,clob_val)
             VALUES (dummy_seq.NEXTVAL,'INSERT','ORDER',P_DATA_JSON);
     END IF;
 FOR I IN(
 SELECT 
  jt.*
FROM 
  JSON_TABLE(
    P_DATA_JSON,
    '$[*]'
    COLUMNS (
      id NUMBER PATH '$.id',
      parent_id NUMBER PATH '$.parent_id',
      n_number VARCHAR2(50) PATH '$.number',
      order_key VARCHAR2(50) PATH '$.order_key',
      created_via VARCHAR2(50) PATH '$.created_via',
      version VARCHAR2(10) PATH '$.version',
      status VARCHAR2(20) PATH '$.status',
      currency VARCHAR2(5) PATH '$.currency',
      date_created TIMESTAMP PATH '$.date_created',
      date_created_gmt TIMESTAMP PATH '$.date_created_gmt',
      date_modified TIMESTAMP PATH '$.date_modified',
      date_modified_gmt TIMESTAMP PATH '$.date_modified_gmt',
      discount_total NUMBER PATH '$.discount_total',
      discount_tax NUMBER PATH '$.discount_tax',
      shipping_total NUMBER PATH '$.shipping_total',
      shipping_tax NUMBER PATH '$.shipping_tax',
      cart_tax NUMBER PATH '$.cart_tax',
      total NUMBER PATH '$.total',
      total_tax NUMBER PATH '$.total_tax',
      prices_include_tax number PATH '$.prices_include_tax',
      customer_id NUMBER PATH '$.customer_id',
      customer_ip_address VARCHAR2(20) PATH '$.customer_ip_address',
      customer_user_agent VARCHAR2(255) PATH '$.customer_user_agent',
      customer_note VARCHAR2(255) PATH '$.customer_note',
      billing_first_name VARCHAR2(50) PATH '$.billing.first_name',
      billing_last_name VARCHAR2(50) PATH '$.billing.last_name',
      billing_company VARCHAR2(50) PATH '$.billing.company',
      billing_address_1 VARCHAR2(255) PATH '$.billing.address_1',
      billing_address_2 VARCHAR2(255) PATH '$.billing.address_2',
      billing_city VARCHAR2(50) PATH '$.billing.city',
      billing_state VARCHAR2(50) PATH '$.billing.state',
      billing_postcode VARCHAR2(20) PATH '$.billing.postcode',
      billing_country VARCHAR2(10) PATH '$.billing.country',
      billing_email VARCHAR2(255) PATH '$.billing.email',
      billing_phone VARCHAR2(20) PATH '$.billing.phone',
      shipping_first_name VARCHAR2(50) PATH '$.shipping.first_name',
      shipping_last_name VARCHAR2(50) PATH '$.shipping.last_name',
      shipping_company VARCHAR2(50) PATH '$.shipping.company',
      shipping_address_1 VARCHAR2(255) PATH '$.shipping.address_1',
      shipping_address_2 VARCHAR2(255) PATH '$.shipping.address_2',
      shipping_city VARCHAR2(50) PATH '$.shipping.city',
      shipping_state VARCHAR2(50) PATH '$.shipping.state',
      shipping_postcode VARCHAR2(20) PATH '$.shipping.postcode',
      shipping_country VARCHAR2(10) PATH '$.shipping.country',
      payment_method VARCHAR2(50) PATH '$.payment_method',
      payment_method_title VARCHAR2(50) PATH '$.payment_method_title',
      transaction_id VARCHAR2(50) PATH '$.transaction_id',
      date_paid TIMESTAMP PATH '$.date_paid',
      date_paid_gmt TIMESTAMP PATH '$.date_paid_gmt',
      date_completed TIMESTAMP PATH '$.date_completed',
      date_completed_gmt TIMESTAMP PATH '$.date_completed_gmt',
      nested PATH '$.line_items[*]' 
      COLUMNS (
        line_item_id NUMBER PATH '$.id',
        line_item_name VARCHAR2(255) PATH '$.name',
        line_item_product_id NUMBER PATH '$.product_id',
        line_item_variation_id NUMBER PATH '$.variation_id',
        line_item_quantity NUMBER PATH '$.quantity',
        line_item_subtotal NUMBER PATH '$.subtotal',
        line_item_subtotal_tax NUMBER PATH '$.subtotal_tax',
        line_item_total NUMBER PATH '$.total',
        line_item_total_tax NUMBER PATH '$.total_tax',
        line_item_sku VARCHAR2(50) PATH '$.sku',
        line_item_price NUMBER PATH '$.price',
        nested path '$.taxes[*]'
            COLUMNS (
        taxes_id NUMBER PATH '$.id',
        taxes_total NUMBER PATH '$.total',
        taxes_subtotal NUMBER PATH '$.subtotal'
        ),
        nested path '$.meta_data[*]'
            COLUMNS (
        meta_data_id NUMBER PATH '$.id',
        meta_data_key VARCHAR2(255) PATH '$.key',
        meta_data_value VARCHAR2(255) PATH '$.value'
        ) 
      ),
   nested path '$.tax_lines[*]'
        COLUMNS (
        tax_lines_id NUMBER PATH '$.id',
        tax_lines_rate_id VARCHAR2(255) PATH '$.rate_id',
        tax_lines_label VARCHAR2(255) PATH '$.label',
        tax_lines_compound VARCHAR2(255) PATH '$.compound',
        tax_lines_tax_total NUMBER PATH '$.tax_total',
        tax_lines_shipping_tax_total NUMBER PATH '$.shipping_tax_total',
        tax_lines_meta_data VARCHAR2(255) PATH '$.meta_data'
        )
        ,
      nested path '$.shipping_lines[*]'
        COLUMNS (
        shipping_lines_id NUMBER PATH '$.id',
        shipping_lines_method_title VARCHAR2(255) PATH '$.method_title',
        shipping_lines_method_id VARCHAR2(255) PATH '$.method_id',
        shipping_lines_total VARCHAR2(255) PATH '$.total',
        shipping_lines_total_tax NUMBER PATH '$.total_tax',
        shipping_lines_taxes VARCHAR2(255) PATH '$.taxes',
        shipping_meta_data VARCHAR2(255) PATH '$.meta_data'
        )
        ,
      fee_lines  VARCHAR2(255) PATH '$.fee_lines',
      coupon_lines  VARCHAR2(255) PATH '$.coupon_lines'
    )
  ) jt) LOOP
    IF P_DML_METHOD=UPPER('INSERT') THEN 

  BEGIN
  IF NVL(V_ORDER_ID,I.ID-1) != I.ID THEN   --Make suer nvl value not matche with i.id in first time
  INSERT INTO WEBSITE_ORDERS
      (
       ID
      ,PARENT_ID
      ,num_ber
      ,ORDER_KEY
      ,CREATED_VIA
      ,VERSION
      ,STATUS
      ,CURRENCY
      ,DATE_CREATED
      ,DATE_CREATED_GMT
      ,DATE_MODIFIED
      ,DATE_MODIFIED_GMT
      ,DISCOUNT_TOTAL
      ,DISCOUNT_TAX
      ,SHIPPING_TOTAL
      ,SHIPPING_TAX
      ,CART_TAX
      ,TOTAL
      ,TOTAL_TAX
      ,PRICES_INCLUDE_TAX
      ,CUSTOMER_ID
      ,CUSTOMER_IP_ADDRESS
      ,CUSTOMER_USER_AGENT
      ,CUSTOMER_NOTE
      ,PAYMENT_METHOD
      ,PAYMENT_METHOD_TITLE
      ,TRANSACTION_ID
      ,DATE_PAID
      ,DATE_PAID_GMT
      ,DATE_COMPLETED
      ,DATE_COMPLETED_GMT
      ,CART_HASH
      )
    VALUES
      (
       i.ID
      ,i.PARENT_ID
      ,i.n_number
      ,i.ORDER_KEY
      ,i.CREATED_VIA
      ,i.VERSION
      ,i.STATUS
      ,i.CURRENCY
      ,i.DATE_CREATED
      ,i.DATE_CREATED_GMT
      ,i.DATE_MODIFIED
      ,i.DATE_MODIFIED_GMT
      ,i.DISCOUNT_TOTAL
      ,i.DISCOUNT_TAX
      ,i.SHIPPING_TOTAL
      ,i.SHIPPING_TAX
      ,i.CART_TAX
      ,i.TOTAL
      ,i.TOTAL_TAX
      ,i.PRICES_INCLUDE_TAX
      ,i.CUSTOMER_ID
      ,i.CUSTOMER_IP_ADDRESS
      ,i.CUSTOMER_USER_AGENT
      ,i.CUSTOMER_NOTE
      ,i.PAYMENT_METHOD
      ,i.PAYMENT_METHOD_TITLE
      ,i.TRANSACTION_ID
      ,i.DATE_PAID
      ,i.DATE_PAID_GMT
      ,i.DATE_COMPLETED
      ,i.DATE_COMPLETED_GMT
      ,NULL--i.CART_HASH
      ) RETURNING ID INTO V_ORDER_RETURN;
      V_ORDER_ID := I.ID;
      END IF;
IF NVL(V_PRODUCT_ID,I.line_item_product_id-1) != I.line_item_product_id THEN   --Make suer nvl value not matche with i.id in first time
    INSERT INTO WEBSITE_LINE_ITEMS
      (
       ORDER_ID
      ,ITEM_ID
      ,NAME
      ,PRODUCT_ID
      ,VARIATION_ID
      ,QUANTITY
      ,TAX_CLASS
      ,SUBTOTAL
      ,SUBTOTAL_TAX
      ,TOTAL
      ,TOTAL_TAX
      ,SKU
      ,PRICE
      )
    VALUES
      (
       i.ID --ORDER_ID
      ,i.line_item_id
      ,i.line_item_name
      ,i.line_item_product_id
      ,i.line_item_variation_id
      ,i.line_item_quantity
      ,NULL --TAX_CLASS
      ,i.line_item_subtotal
      ,i.line_item_subtotal_tax
      ,i.line_item_total
      ,i.line_item_total_tax
      ,i.line_item_sku
      ,i.line_item_price
      );
V_PRODUCT_ID := I.line_item_product_id;
END IF;
IF NVL(V_BILLING,'not match') != I.billing_LAST_NAME THEN --Make suer nvl value not matche first time


                INSERT INTO  WEBSITE_BILLING_ADDRESS
      (
       ID
      ,INVOICE_NO
      ,CUSTOMER_ID
      ,FIRST_NAME
      ,LAST_NAME
      ,COMPANY
      ,ADDRESS_1
      ,ADDRESS_2
      ,CITY
      ,STATE
      ,POSTCODE
      ,COUNTRY
      ,EMAIL
      ,PHONE,
      ORDER_ID
      )
    VALUES
      (
       WEBSITE_BILLING_ADDRESS_SEQ.NEXTVAL
      ,null
      ,i.ID  --Customer_id
      ,i.billing_FIRST_NAME
      ,i.billing_LAST_NAME
      ,i.billing_COMPANY
      ,i.billing_ADDRESS_1
      ,i.billing_ADDRESS_2
      ,i.billing_CITY
      ,i.billing_STATE
      ,i.billing_POSTCODE
      ,i.billing_COUNTRY
      ,i.billing_EMAIL
      ,i.billing_PHONE,
       V_ORDER_ID
      );
V_BILLING := I.billing_LAST_NAME;
END IF;
IF NVL(V_SHIPPING,'not match') != I.shipping_LAST_NAME THEN   --Make suer nvl value not matche first time
          INSERT INTO WEBSITE_SHIPPING_ADDRESS
      (
       ID
      ,INVOICE_NO
      ,CUSTOMER_ID
      ,FIRST_NAME
      ,LAST_NAME
      ,COMPANY
      ,ADDRESS_1
      ,ADDRESS_2
      ,CITY
      ,STATE
      ,POSTCODE
      ,COUNTRY,
      ORDER_ID
      )
    VALUES
      (
       WEBSITE_SHIPPING_ADDRESS_SEQ.NEXTVAL
      ,null
      ,i.ID  --Customer_id
      ,i.shipping_FIRST_NAME
      ,i.shipping_LAST_NAME
      ,i.shipping_COMPANY
      ,i.shipping_ADDRESS_1
      ,i.shipping_ADDRESS_2
      ,i.shipping_CITY
      ,i.shipping_STATE
      ,i.shipping_POSTCODE
      ,i.shipping_COUNTRY,
      V_ORDER_ID
      );
V_SHIPPING := I.shipping_LAST_NAME;
END IF;
IF nvl(V_SHIPPING_METHOD,'not match') != I.shipping_lines_method_title THEN   --Make suer nvl value not matche  first time
    INSERT INTO WEBSITE_SHIPPING_LINES
      (
       ORDER_ID
      ,LINE_ID
      ,METHOD_TITLE
      ,METHOD_ID
      ,TOTAL
      ,TOTAL_TAX
      )
    VALUES
      (
       V_ORDER_ID --ORDER_ID
      ,i.shipping_lines_id
      ,i.shipping_lines_method_title
      ,i.shipping_lines_method_id
      ,i.shipping_lines_total
      ,i.shipping_lines_total_tax
      );
V_SHIPPING_METHOD := I.shipping_lines_method_title;
END IF;
        IF V_ORDER_RETURN IS NOT NULL THEN
        UPDATE WEBSITE_ORDERS SET ORDER_JSON =P_DATA_JSON WHERE ID=V_ORDER_RETURN;
        P_STATUS := 201;
        P_RESULT :='Order No '||V_ORDER_RETURN||' Created Succsessfully';
        ELSE 
        V_REFERENCE_NO:=TO_NUMBER(TO_CHAR(SYSTIMESTAMP,'YYYYMMDDHH24MISSFF3'));
                    INSERT INTO dummy (id,val1,val2,clob_val,REFERENCE_NO)
             VALUES (dummy_seq.NEXTVAL,'INSERT','ORDER',P_DATA_JSON,V_REFERENCE_NO);
        P_STATUS := 400;
        P_RESULT :='Something wrong, Contact your developer with error code - '||V_REFERENCE_NO;
        END IF;
        
    EXCEPTION
        WHEN OTHERS
        THEN
            P_STATUS := 400;
            P_RESULT := SQLERRM;
            IF P_RESULT='ORA-00001: unique constraint (LAM.SYS_C0043646) violated' THEN
            P_RESULT:= 'Order ID already available';
            END IF;
        
        END; 
        
    END IF;
    
   END LOOP;

 END;
PROCEDURE WEBSITE_GET_ITEMS(
         P_BRAND        IN VARCHAR2,
         P_CATEGORY     IN VARCHAR2,
         p_SKU          IN VARCHAR2,
         P_DATA_JSON OUT SYS_REFCURSOR) AS
L_CURSOR    SYS_REFCURSOR;  
BEGIN

OPEN L_CURSOR FOR
SELECT SIDT.ITEM_ID,
       IC.CAT_NAME_EN    Category,
       SIDT.ITEM_NAME_AR,
       SIDT.ITEM_NAME_EN,
       SIDT.COM_ID,
       CASE
           WHEN SIDT.STATUS = 'Y'
           THEN
               '<span class="fa fa-check" aria-hidden="true"></span>'
           WHEN SIDT.STATUS = 'N'
           THEN
               '<span class="fa fa-ban" aria-hidden="true"></span>'
       END               AS STATUS,
       U.UNIT_NAME_AR,
       SIDT.UNIT_PRICE,
       SIDT.TAX_TYPE_ID,
       SIDT.MAX_UNIT,
       SIDT.MIN_UNIT,
       SIDT.COST_CENTRE_ID,
       SIDT.POLICY_FOR_DISPENSING_ITEM_ID,
       SIDT.ITEM_TYPE,
       SIDT.INVENTORY_TYPE,
       SIDT.ITEM_BARCODE,
       SIDT.ITEM_CODE,
       B.NAME_EN        AS BRAND,
       SIDT.sku_size,
       SIDT.Color,
       SIDT.sku_Length,
       SIDT.Width,
       SIDT.Height,
       SIDT.Diameter,
       SIDT.Weight,
       SIDT.Damage_qty,
       SIDT.Total_Qty,
       SIDT.Remarks,
       SIDT.sku,
       SIDT.PARENT_SKU,
       SIDT.QUANTITY_ON_HAND,
       SIDT.PURCHASE_DESCRIPTION,
       CASE WHEN SIDT.PRODUCT_IMAGE_NAME IS NOT NULL THEN
       '<img  src="https://your domain/'||SIDT.PRODUCT_IMAGE_NAME||';">'  --set your image directory
       ELSE 
        '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">
  <circle cx="50" cy="50" r="40" stroke="black" stroke-width="2" fill="none" />
  <line x1="20" y1="20" x2="80" y2="80" stroke="black" stroke-width="2" />
  <line x1="20" y1="80" x2="80" y2="20" stroke="black" stroke-width="2" />
  <text x="30" y="70" font-size="20" font-weight="bold" fill="black">No</text>
  <text x="30" y="45" font-size="20" font-weight="bold" fill="black">Image</text>
</svg>' END AS PRODUCT_IMAGE_NAME_URL
  FROM STR_SETUP_ITEM_DTL  SIDT,
       STR_ITEM_BRAND      B,
       STR_ITEM_UNIT       U,
       STR_ITEM_CATEGORY   IC
 WHERE     SIDT.BRAND_ID = B.ID(+)
       AND SIDT.UOM = U.UNIT_ID(+)
       AND SIDT.CAT_ID = IC.CAT_ID
       AND (SIDT.SKU=P_SKU OR P_SKU IS NULL)
       AND (IC.CAT_NAME_EN=P_CATEGORY OR P_CATEGORY IS NULL)
       AND (B.NAME_EN=P_BRAND OR P_BRAND IS NULL)
       ORDER BY SIDT.ITEM_NAME_EN;
P_DATA_JSON:=L_CURSOR;
END;
 PROCEDURE WEBSITE_CUSTOMER_GET(
         P_ID       IN WEBSITE_CUSTOMERS.ID%TYPE,
         P_DATA_JSON OUT SYS_REFCURSOR) IS
 L_CURSOR SYS_REFCURSOR;   
 BEGIN
 OPEN L_CURSOR FOR
--SELECT
--  JSON_OBJECT(
--    'id' VALUE c.id,
----    'date_created' VALUE TO_CHAR(c.date_created, 'YYYY-MM-DD"T"HH24:MI:SS'),
----    'date_created_gmt' VALUE TO_CHAR(c.date_created AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
----    'date_modified' VALUE TO_CHAR(c.date_modified, 'YYYY-MM-DD"T"HH24:MI:SS'),
----    'date_modified_gmt' VALUE TO_CHAR(c.date_modified AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
--    'email' VALUE c.email,
--    'first_name' VALUE c.first_name,
--    'last_name' VALUE c.last_name,
--    'role' VALUE c.role,
--    'username' VALUE c.username,
--    'billing' VALUE JSON_OBJECT(
--                  'first_name' VALUE b.first_name,
--                  'last_name' VALUE b.last_name,
--                  'company' VALUE b.company,
--                  'address_1' VALUE b.address_1,
--                  'address_2' VALUE b.address_2,
--                  'city' VALUE b.city,
--                  'state' VALUE b.state,
--                  'postcode' VALUE b.postcode,
--                  'country' VALUE b.country,
--                  'email' VALUE b.email,
--                  'phone' VALUE b.phone
--                ),
--    'shipping' VALUE JSON_OBJECT(
--                   'first_name' VALUE s.first_name,
--                   'last_name' VALUE s.last_name,
--                   'company' VALUE s.company,
--                   'address_1' VALUE s.address_1,
--                   'address_2' VALUE s.address_2,
--                   'city' VALUE s.city,
--                   'state' VALUE s.state,
--                   'postcode' VALUE s.postcode,
--                   'country' VALUE s.country
--                 ),
--    'is_paying_customer' VALUE c.is_paying_customer,
--    'avatar_url' VALUE c.avatar_url
--  ) AS customer_json
--FROM
--  WEBSITE_customerS c
--  JOIN WEBSITE_BILLING_ADDRESS b ON c.id = b.customer_id
--  JOIN WEBSITE_SHIPPING_ADDRESS s ON c.id = s.customer_id
--WHERE
--  c.id = P_ID;
SELECT C.*,B.*,S.*
FROM
  WEBSITE_customerS c
  JOIN WEBSITE_BILLING_ADDRESS b ON c.id = b.customer_id
  JOIN WEBSITE_SHIPPING_ADDRESS s ON c.id = s.customer_id
WHERE
  c.id = P_ID OR P_ID is null;
 P_DATA_JSON:=L_CURSOR;
 END;
END;
/
