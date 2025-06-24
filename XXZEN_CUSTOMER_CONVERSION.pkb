CREATE OR REPLACE PACKAGE BODY xxzen_customer_conversion
AS

-- begin
--  fnd_global.apps_initialize( user_id     => 1318
--                              ,resp_id      => 50559
--    ,resp_appl_id =>222 );
--xxzen_CUSTOMER_conversion.xxzen_CUSTOMER_INTERFACE;
-- End;
--
PROCEDURE xxzen_customer_interface
AS

cursor get_party is
SELECT Party
      ,account_name
      ,reference
      ,customer_profile_class
      ,customer_payment_terms
      ,customer_email
      ,customer_url
      ,customer_date_established
      ,customer_price_list
      ,salesperson
      ,customer_credit_hold_flag
      ,customer_credit_amount
      ,warehouse
      ,order_type
      ,comments
      ,tax_reg_no
   FROM (SELECT trim(account_name)            Party
               ,trim(account_name)            account_name
               ,trim(reference)               reference
               ,trim(customer_profile_class)  customer_profile_class
               ,trim(customer_payment_terms)  customer_payment_terms
               ,trim(customer_email)          customer_email
               ,trim(customer_url)            customer_url
               ,customer_date_established     customer_date_established
               ,trim(customer_price_list)     customer_price_list
               ,trim(salesperson)             salesperson
               ,trim(customer_credit_hold_flag) customer_credit_hold_flag
               ,customer_credit_amount        customer_credit_amount 
               ,trim(warehouse)               warehouse    
               ,trim(order_type)              order_type
               ,trim(comments)                comments
               ,trim(tax_reg_no)              tax_reg_no
               ,row_number() over (partition by trim(account_name)
	                ORDER BY trim(account_name)
                            ,trim(account_name)
                            ,customer_date_established
                            ,trim(reference)
                     DESC NULLS LAST ) cust_row_num
         FROM xxzen_ra_cust_int_stg
        WHERE customer_name IS NOT NULL AND load_status IS NULL )
 WHERE cust_row_num = 1
-- AND (party = 'BLUE RIBBON STAIRS' OR party = 'DAVID WEEKLEY HOMES')
ORDER BY reference ;
--
CURSOR cur_cust_main (pCustname varchar2)
IS
SELECT trim(account_name)           customer_name
      ,trim(account_name)           account_name
      ,trim(customer_type)          customer_type
      ,trim(tax_reg_no)             tax_reg_no
      ,trim(taxpayer_id)            taxpayer_id
      ,trim(address_line_1)         address_line_1
      ,trim(address_line_2)         address_line_2
      ,trim(address_line_3)         address_line_3
      ,trim(address_line_4)         address_line_4
      ,trim(country)                country
      ,trim(city)                   city
      ,trim(state)                  state
      ,trim(zip)                    zip
      ,trim(county)                 county
      ,trim(reference)              reference
      ,trim(bill_to_flag)           bill_to_flag
      ,trim(primary_bill_to_flag)   primary_bill_to_flag
      ,trim(bill_to_contact_lname)  bill_to_contact_lname
      ,trim(bill_to_contact_fname)  bill_to_contact_fname
      ,trim(bill_to_contact_phone)  bill_to_contact_phone
      ,trim(bill_to_contact_ph_ext) bill_to_contact_ph_ext
      ,trim(bill_to_contact_fax)    bill_to_contact_fax
      ,trim(ship_to_flag)           ship_to_flag
      ,trim(primary_ship_to_flag)   primary_ship_to_flag
      ,trim(ship_to_contact_lname)  ship_to_contact_lname
      ,trim(ship_to_contact_fname)  ship_to_contact_fname
      ,trim(ship_to_contact_phone ) ship_to_contact_phone
      ,trim(customer_profile_class) customer_profile_class
      ,trim(customer_payment_terms) customer_payment_terms
      ,trim(customer_email)         customer_email
      ,trim(customer_url)           customer_url
      ,customer_date_established    customer_date_established
      ,trim(customer_price_list)    customer_price_list
      ,trim(salesperson)            salesperson
      ,trim(customer_credit_hold_flag) customer_credit_hold_flag
      ,customer_credit_amount       customer_credit_amount
      ,trim(warehouse)              warehouse
      ,trim(order_type)             order_type
      ,trim(comments)               comments
 FROM xxzen_ra_cust_int_stg
WHERE trim(account_name) = pCustname
  AND load_status IS NULL 
ORDER BY reference asc, bill_to_flag desc;
-- 
CURSOR cur_nsp_records IS
SELECT customer_name 
 FROM xxzen_ra_cust_int_stg
WHERE (account_name like '*%'
     OR state IS NULL
     OR zip IS NULL 
     OR city IS NULL 
     OR address_line_1 IS NULL
     ) FOR UPDATE;
--
-- cursor to validate price list
CURSOR cur_price_list (c_list_name VARCHAr2) IS
SELECT price_list_id list_header_id
  FROM oe_price_lists_vl
 WHERE upper(name) = upper(c_list_name) ;
p_list_header_id       NUMBER ;
--
-- cursor to validate profile class
CURSOR cur_profile_class (c_profile_class VARCHAR2) IS
SELECT profile_class_id
  FROM hz_cust_profile_classes
 WHERE upper(name) = upper(c_profile_class) ;
p_profile_class_id     NUMBER ;
--
-- cursor to payment terms
CURSOR cur_payment_terms (c_payment_terms VARCHAR2) IS
SELECT term_id
  FROM ra_terms
 WHERE upper(name) = upper(c_payment_terms) ;
p_payment_terms_id     NUMBER ;
--
-- cursor to validate territory list
CURSOR cur_territories (c_territory_name VARCHAr2) IS
SELECT territory_code
  FROM fnd_territories_vl
 WHERE territory_short_name = c_territory_name ;
p_territory_code       VARCHAR2(10) ;
--
-- cursor to SalesPerson
CURSOR cur_salespersons (c_salesperson VARCHAR2) IS
SELECT salesrep_id
  FROM ra_salesreps
 WHERE upper(name) = upper(c_salesperson) ;
p_primary_salesrep_id     NUMBER ;
--
-- cursor to Warehouse
CURSOR cur_warehouse (c_warehouse VARCHAR2) IS
SELECT organization_id
  FROM org_organization_definitions
 WHERE upper(organization_code) = upper(c_warehouse) ;
p_warehouse_id     NUMBER ;
--
-- cursor to Order Type
CURSOR cur_Order_type (c_order_type VARCHAR2) IS
SELECT transaction_type_id
  FROM oe_transaction_types_vl
 WHERE upper(name) = upper(c_order_type) ;
p_order_type_id     NUMBER ;
--
--
--USER DEFINED EXCEPTION FOR VALIDATION VIOLATION
e_validation_exception EXCEPTION;
whereami               number;
--
oStatus              varchar2(1);
oMsgCount            number;
oMsgData             varchar2(2000);
--
pOrganizationRec     HZ_PARTY_V2PUB.organization_rec_type;
oPartyId	     hz_parties.party_id%type;
oPartyNumber	     hz_parties.party_number%type;
oProfileId	     number;
--
pCustAccountRec	     HZ_CUST_ACCOUNT_V2PUB.cust_account_rec_type;
pPartyRec	     HZ_PaRTY_V2PUB.party_rec_type;
pProfileRec          hz_customer_profile_v2pub.customer_profile_rec_type;
oCustAccountId	     hz_cust_accounts.cust_account_id%type;
oCustAccountNo	     hz_cust_accounts.account_number%type;
--
pLocationRec	     HZ_LOCATION_V2PUB.location_rec_type;
oLocationId	     hz_locations.location_id%type;
--
pPartySiteRec	     hz_party_site_v2pub.PARTY_SITE_REC_TYPE;
oPartySiteId	     hz_party_sites.party_site_id%type;
oPartySiteNo	     hz_party_sites.PARTY_SITE_NUMBER%type;
--
pCustAcctSiteRec     HZ_CUST_ACCOUNT_SITE_V2PUB.cust_acct_site_rec_type;
oCustAcctSiteId      hz_cust_acct_sites.CUST_ACCT_SITE_ID%type;
--
pCustAcctSiteUseRec  HZ_CUST_ACCOUNT_SITE_V2PUB.CUST_SITE_USE_REC_TYPE;
pCustomerProfile     HZ_CUSTOMER_PROFILE_V2PUB.CUSTOMER_PROFILE_REC_TYPE;
oCustAcctSiteUseId   number;
pBillToSiteUseId     number;
pCustAcctId          number;
--
pCustProfileAmt       HZ_CUSTOMER_PROFILE_V2PUB.CUST_PROFILE_AMT_REC_TYPE;
oCustAcctProfileAmtId number;
pCustAcctProfileAmtId number;
pCustAccountProfileId number;
pObjectVersionNumber  number;
pCurrencyCode         VARCHAR2(10);
--
pPersonRec           HZ_PARTY_V2PUB.person_rec_type;
oPpartyId            hz_parties.party_id%TYPE ;
oPpartyNumber        hz_parties.party_Number%TYPE ;
oPprofileId          NUMBER ;
--
pOrgContactRec       HZ_PARTY_CONTACT_V2PUB.ORG_CONTACT_REC_TYPE;
oOcPartyId           hz_parties.party_id%TYPE ;
oOcPartyNumber       hz_parties.party_Number%TYPE ;
oOcPartyRelNumber    hz_org_contacts.contact_number%TYPE ;
oOcPartyRelId        hz_party_relationships.PARTY_RELATIONSHIP_ID%TYPE ;
oOcOrgContactId      hz_org_contacts.ORG_CONTACT_ID%TYPE ;
--
pCustAcctRoleRec     HZ_CUST_ACCOUNT_ROLE_V2PUB.cust_account_role_rec_type ;
oCustAcctRoleId      hz_cust_account_roles.CUST_ACCOUNT_ROLE_ID%TYPE ;
--
pContactPointRec     HZ_CONTACT_POINT_V2PUB.CONTACT_POINT_REC_TYPE;
pEdiRec              HZ_CONTACT_POINT_V2PUB.EDI_REC_TYPE;
pEmailRec            HZ_CONTACT_POINT_V2PUB.EMAIL_REC_TYPE;
pPhoneRec            HZ_CONTACT_POINT_V2PUB.PHONE_REC_TYPE;
pTelexRec            HZ_CONTACT_POINT_V2PUB.TELEX_REC_TYPE;
pWebRec              HZ_CONTACT_POINT_V2PUB.WEB_REC_TYPE;
oContactPointId      NUMBER ;
--
pRoleResponsibilityRec  HZ_CUST_ACCOUNT_ROLE_V2PUB.role_responsibility_rec_type ;
oResponsibilityId       NUMBER ;
--
prefix               varchar2(3):='';
-- USER DEFINE FLAG TO CONTINUE CONTACT CREATION AFTER SITE USE
p_proceed_flag       VARCHAR2(1) := 'N' ;
--
p_reference          VARCHAR2(240) ;
p_old_reference      VARCHAR2(240) := '99';
p_postfix              VARCHAR2(1) := 'A' ;
BEGIN
   -- Update customer records having basic data problem
   FOR rec_nsp_records IN cur_nsp_records
   LOOP
	UPDATE 	xxzen_ra_cust_int_stg
	SET	load_status = 'Not Selected for Customer Conversion '
        WHERE CURRENT OF cur_nsp_records;
   END LOOP ;

   FOR c1 IN get_party
   LOOP
      whereami:=1;
      -- Get valid values for price list and customer profile
      p_profile_class_id := null ;
      p_list_header_id := null ;
      p_payment_terms_id := null ;
      p_primary_salesrep_id := null ;
      p_warehouse_id := null ;
      p_order_type_id := null ;
      FOR rec_price_list IN cur_price_list(c1.customer_price_list)
      LOOP
         p_list_header_id := rec_price_list.list_header_id ;
      END LOOP ;
      --
      FOR rec_profile_class IN cur_profile_class (c1.customer_profile_class)
      LOOP
         p_profile_class_id := rec_profile_class.profile_class_id ;
      END LOOP ;
      --
      FOR rec_payment_terms IN cur_payment_terms (c1.customer_payment_terms)
      LOOP
         p_payment_terms_id := rec_payment_terms.term_id ;
      END LOOP ;
      --
      FOR rec_salespersons IN cur_salespersons (c1.salesperson)
      LOOP
         p_primary_salesrep_id := rec_salespersons.salesrep_id ;
      END LOOP ;
      --
      FOR rec_warehouse IN cur_warehouse (c1.warehouse)
      LOOP
         p_warehouse_id := rec_warehouse.organization_id ;
      END LOOP ;
      --
      FOR rec_Order_type IN cur_Order_type (c1.Order_type)
      LOOP
         p_Order_type_id := rec_Order_type.transaction_type_id ;
      END LOOP ;
      -- Start Create Party
      oPartyId:=null;
      pOrganizationRec:=null;
      --initialize the values
      oStatus         :=null;
      oMsgCount       :=null;
      oMsgData        :=null;
      -- Create the Party Organization Record
      pOrganizationRec.organization_name:=prefix||c1.party;
      pOrganizationRec.party_rec.orig_system_reference := prefix||c1.reference ;
      pOrganizationRec.tax_reference := c1.tax_reg_no ;
      pOrganizationRec.created_by_module:='TCA_V1_API';
      SELECT hz_parties_s.nextval
        INTO pPartyRec.party_id
        FROM dual;
      --
      whereami:=2;
      HZ_PARTY_V2PUB.create_organization (
                     p_init_msg_list => 'T',
                     p_organization_rec => pOrganizationRec,
                     x_return_status => oStatus,
                     x_msg_count => oMsgCount,
                     x_msg_data => oMsgData,
                     x_party_id => oPartyId,
                     x_party_number => oPartyNumber,
                     x_profile_id => oProfileId);

      if oStatus <> 'S' then
         IF oMsgCount >1 then
            FOR I IN 1..oMsgCount
            LOOP
               dbms_output.put_line(' Party Organization Record '||I||SubStr(FND_MSG_PUB.Get(p_encoded => FND_API.G_FALSE ), 1, 255));
            END LOOP;
         ELSE
            dbms_output.put_line(' Party Organization Record '||oMsgData);
         END IF;
         RAISE e_validation_exception ;
      else
	 --initialize the values
         oStatus         :=null;
         oMsgCount       :=null;
         oMsgData        :=null;
         -- Call the Customer Account API
         whereami:=3;
         -- Get Orig System Refrence Value
         IF INSTR (p_old_reference,'-',-1) != 0 THEN
            IF SUBSTR(p_old_reference,1,INSTR(p_old_reference,'-',-1)-1) = c1.reference THEN
               p_postfix := TRANSLATE(SUBSTR(p_old_reference,INSTR(p_old_reference,'-',-1)+1,1),
                            'ABCDEFGHIJKLMNOPQRSTUVWXYZ','BCDEFGHIJKLMNOPQRSTUVWXYZZ') ;
              p_reference := c1.reference ||'-'|| p_postfix ;
            ELSE
              p_reference := c1.reference ;
            END IF;
         ELSIF p_old_reference = c1.reference THEN
              p_postfix := 'A' ;
              p_reference := c1.reference ||'-'|| p_postfix ;
         ELSE
              p_reference := c1.reference ;
         END IF ;
         p_old_reference := p_reference ;
         pOrganizationRec.party_rec.party_id :=oPartyId;  --party id from top
         pCustAccountRec.account_name:=prefix||c1.account_name;
         pCustAccountRec.orig_system_reference := prefix||p_reference ; --c1.reference ;
         pCustAccountRec.tax_code:=null;
         pCustAccountRec.price_list_id:= p_list_header_id ;
         pCustAccountRec.primary_salesrep_id:= p_primary_salesrep_id ;
         --pCustAccountRec.warehouse_id:= p_warehouse_id;
         --pCustAccountRec.order_type_id:= p_order_type_id;
         pCustAccountRec.comments:= c1.comments ;
	 pCustAccountRec.attribute1:= TO_CHAR(c1.customer_date_established,'RRRR-MON-DD');
	 pProfileRec.profile_class_id:= p_profile_class_id;
	 pProfileRec.standard_terms:= p_payment_terms_id;
	 pProfileRec.credit_hold:= c1.customer_credit_hold_flag;
         pCustAccountRec.created_by_module:='TCA_V1_API';
/*	 SELECT hz_cust_accounts_s.nextval
           INTO pCustAccountRec.account_number
           FROM dual;--**** */
         whereami:=4;
	 HZ_CUST_ACCOUNT_V2PUB.create_cust_account (
                               p_init_msg_list =>'T',
                               p_cust_account_rec => pCustAccountRec,  -- Customer Account Record
                               p_organization_rec => pOrganizationRec, -- Party Organization Record
                               p_customer_profile_rec => pProfileRec,
                               p_create_profile_amt => FND_API.G_TRUE,
                               x_cust_account_id => oCustAccountId,
                               x_account_number => oCustAccountNo,
                               x_party_id => oPartyId,
                               x_party_number => oPartyNumber,
                               x_profile_id => oProfileId,
                               x_return_status =>oStatus,
                               x_msg_count => oMsgCount,
                               x_msg_data => oMsgData);
         if oStatus <> 'S' then
            IF oMsgCount >1 THEN
               FOR I IN 1..oMsgCount
               LOOP
                  dbms_output.put_line(' Customer Account Record '||I||SubStr(FND_MSG_PUB.Get(p_encoded => FND_API.G_FALSE ), 1, 255));
               END LOOP;
            ELSE
               dbms_output.put_line(' Customer Account Record '||oMsgData);
            END IF;
            RAISE e_validation_exception ;
         else
            pCustProfileAmt := null ;
            pCustAcctProfileAmtId := null;
            pCustAccountProfileId := null;
            pCurrencyCode := null ;
            BEGIN 
              SELECT cust_acct_profile_amt_id
                    ,cust_account_profile_id
                    ,currency_code
                    ,object_version_number
                INTO pCustAcctProfileAmtId
                    ,pCustAccountProfileId
                    ,pCurrencyCode
                    ,pObjectVersionNumber
                FROM hz_cust_profile_amts
               WHERE cust_account_id = oCustAccountId 
                 AND currency_code = 'USD';
            EXCEPTION
               WHEN no_data_found THEN
                 pCustAcctProfileAmtId := NULL ;
                 SELECT cust_account_profile_id 
                   INTO pCustAccountProfileId 
                   FROM hz_customer_profiles
                  WHERE cust_account_id = oCustAccountId ;
            END ;
            IF c1.customer_credit_amount > 0 AND pCustAcctProfileAmtId IS NULL THEN
              -- dbms_output.put_line(' Profile Amt '||oProfileId||' - '||oCustAccountId ||' - '||p_profile_class_id||' cnt'||pObjectVersionNumber);
               pCustProfileAmt.cust_account_profile_id :=  pCustAccountProfileId ;
               pCustProfileAmt.currency_code := NVL(pCurrencyCode,'USD') ;
               pCustProfileAmt.trx_credit_limit := c1.customer_credit_amount ;
               pCustProfileAmt.overall_credit_limit := c1.customer_credit_amount ;
               pCustProfileAmt.created_by_module := 'TCA_V1_API';
               whereami := 4.1 ;
               HZ_CUSTOMER_PROFILE_V2PUB.create_cust_profile_amt (
                                         p_init_msg_list => 'T' ,
                                         p_check_foreign_key => 'T',
                                         p_cust_profile_amt_rec => pCustProfileAmt ,
                                         x_cust_acct_profile_amt_id => oCustAcctProfileAmtId ,
                                         x_return_status =>oStatus,
                                         x_msg_count => oMsgCount,
                                         x_msg_data => oMsgData);

              if oStatus <> 'S' then
                 IF oMsgCount >1 THEN
                   FOR I IN 1..oMsgCount
                   LOOP
                      dbms_output.put_line('Customer Profile Amount'||I||SubStr(FND_MSG_PUB.Get(p_encoded => FND_API.G_FALSE ), 1, 255));
                   END LOOP;
                 ELSE
                   dbms_output.put_line('Customer Profile Amount '||oMsgData);
                 END IF;
               RAISE e_validation_exception ;
              end if ;
            END IF ; -- end create profile Amount
            IF c1.customer_credit_amount > 0 AND pCustAcctProfileAmtId IS NOT NULL THEN
               --dbms_output.put_line(' Profile Amt '||oProfileId||' - '||oCustAccountId ||' - '||p_profile_class_id);
               pCustProfileAmt.cust_acct_profile_amt_id := pCustAcctProfileAmtId ;
               pCustProfileAmt.cust_account_profile_id :=  pCustAccountProfileId ;
               pCustProfileAmt.currency_code := pCurrencyCode ;
               pCustProfileAmt.trx_credit_limit := c1.customer_credit_amount ;
               pCustProfileAmt.overall_credit_limit := c1.customer_credit_amount ;
               pCustProfileAmt.created_by_module := 'TCA_V1_API';
               whereami := 4.1 ;
               HZ_CUSTOMER_PROFILE_V2PUB.update_cust_profile_amt (
                                         p_init_msg_list => 'T' ,
                                         p_cust_profile_amt_rec => pCustProfileAmt ,
                                         p_object_version_number => pObjectVersionNumber ,
                                         x_return_status =>oStatus,
                                         x_msg_count => oMsgCount,
                                         x_msg_data => oMsgData);

              if oStatus <> 'S' then
                 IF oMsgCount >1 THEN
                   FOR I IN 1..oMsgCount
                   LOOP
                      dbms_output.put_line('Update Customer Profile Amount '||I||SubStr(FND_MSG_PUB.Get(p_encoded => FND_API.G_FALSE ), 1, 255));
                   END LOOP;
                 ELSE
                   dbms_output.put_line('Update Customer Profile Amount '||oMsgData);
                 END IF;
               RAISE e_validation_exception ;
              end if ;
            END IF ; -- end create profile Amount
             -- do the addresses now
            FOR c2 IN cur_cust_main(c1.party)
            LOOP
               IF (/*c2.country IS NULL OR*/ c2.address_line_1 IS NULL OR c2.zip IS NULL
                  OR c2.city IS NULL OR c2.state IS NULL /*OR c2.county IS NULL */
                  OR ( c2.ship_to_flag IS NULL AND c2.bill_to_flag IS NULL )) THEN
                 dbms_output.put_line(' Address attribute Check: Null value in one of the following attributes for Customer '||c1.party );
                 dbms_output.put_line(' Country | Address Line 1 | Zip | City | State | County | (Ship to Y/N and Bill to Y/N) ');
                 dbms_output.put_line(NVL(c2.country,'null')||'|'||NVL(c2.address_line_1,'null')
                                     ||'|'||NVL(c2.zip,'null')||'|'||NVL(c2.City,'null')||'|'||NVL(c2.State,'null')||'|'||NVL(c2.County,'null')
                                     ||'|('||NVL(c2.ship_to_flag,'null')||'|'||NVL(c2.bill_to_flag,'null')||')');
                 RAISE e_validation_exception ;
              ELSE
               p_territory_code := null ;
               p_profile_class_id := null;
               FOR rec_territories IN cur_territories (c2.country)
               LOOP
                  p_territory_code := rec_territories.territory_code ;
               END LOOP ;
               --
              FOR rec_profile_class IN cur_profile_class (c2.customer_profile_class)
              LOOP
                 p_profile_class_id := rec_profile_class.profile_class_id ;
              END LOOP ;
              --initialize the values
               pLocationRec            :=null;
               pPartySiteRec           :=null;
               pCustAcctSiteRec        :=null;
               pCustAcctSiteUseRec     :=null;
               pCustomerProfile        :=null;
               pPersonRec              :=null;
               pOrgContactRec          :=null;
               pCustAcctRoleRec        :=null;
               pContactPointRec        :=null;
               pEdiRec                 :=null;
               pEmailRec               :=null;
               pPhoneRec               :=null;
               pTelexRec               :=null;
               pWebRec                 :=null;
               pRoleResponsibilityRec  :=null;
               oStatus         :=null;
               oMsgCount       :=null;
               oMsgData        :=null;
               whereami:=5;
               pLocationRec.country:= NVL(p_territory_code,'US') ;
               pLocationRec.postal_code:=(c2.zip);
               pLocationRec.address1:=rtrim(c2.address_line_1); --ship to customer name
               pLocationRec.address2:=rtrim(c2.address_line_2);
               pLocationRec.address3:=rtrim(c2.address_line_3);
               pLocationRec.address4:=rtrim(c2.address_line_4);
               pLocationRec.state:=(c2.state); -- is mandatory
               pLocationRec.city:=c2.city;
               pLocationRec.county:=nvl(c2.county,c2.city); --for the time being (will be updated for Sales Tax later)
               pLocationRec.created_by_module:='TCA_V1_API';
               whereami:=6;
               HZ_LOCATION_V2PUB.create_location (
                                 p_init_msg_list => 'T',
                                 p_location_rec => pLocationRec,
                                 x_location_id => oLocationId,
                                 x_return_status => oStatus,
                                 x_msg_count => oMsgCount,
                                 x_msg_data => oMsgData);
               if oStatus <> 'S' then
                  IF oMsgCount >1 THEN
                     FOR I IN 1..oMsgCount
                     LOOP
                        dbms_output.put_line(' Customer Location Record '||I||SubStr(FND_MSG_PUB.Get(p_encoded => FND_API.G_FALSE ), 1, 255));
                     END LOOP;
                  ELSE
                     dbms_output.put_line(' Customer Location Record '||oMsgData);
                  END IF;
                  RAISE e_validation_exception ;
	       else
		  --initialize the values
                  oStatus         :=null;
                  oMsgCount       :=null;
                  oMsgData        :=null;
                  -- create a party site now
                  whereami:=7;
                  pPartySiteRec.party_id:= oPartyId;
                  pPartySiteRec.location_id:=oLocationId;
                  pPartySiteRec.orig_system_reference := prefix||p_reference ; --c1.reference ;
                 /* SELECT hz_party_number_s.nextval
                    INTO pPartySiteRec.party_site_number
                    FROM dual;*/
                  pPartySiteRec.created_by_module:='TCA_V1_API';
                  whereami:=8;
                  HZ_PARTY_SITE_V2PUB.create_party_site(
                                      p_init_msg_list => 'T',
                                      p_party_site_rec => pPartySiteRec,
                                      x_party_site_id => oPartySiteId,
                                      x_party_site_number => oPartySiteNo,
                                      x_return_status => oStatus,
                                      x_msg_count => oMsgCount,
                                      x_msg_data => oMsgData);
                  if oStatus <> 'S' then
                     IF oMsgCount >1 THEN
                        FOR I IN 1..oMsgCount
                        LOOP
                           dbms_output.put_line(' Customer Party Site Record '||I||SubStr(FND_MSG_PUB.Get(p_encoded => FND_API.G_FALSE ), 1, 255));
                        END LOOP;
                     ELSE
                        dbms_output.put_line(' Customer  Party Site Record '||oMsgData);
                     END IF;
                     RAISE e_validation_exception ;
                  else
                     --initialize the values
                     oStatus         :=null;
                     oMsgCount       :=null;
                     oMsgData        :=null;
                     -- create the customer account site now
                     whereami:=9;
                     pCustAcctSiteRec.cust_account_id := oCustAccountId;
                     pCustAcctSiteRec.party_site_id := oPartySiteId;
                     pCustAcctSiteRec.language:='US';
                     pCustAcctSiteRec.created_by_module:='TCA_V1_API';
                     pCustAcctSiteRec.orig_system_reference := prefix||p_reference||'-'||oPartySiteId ;
                     whereami:=10;
                     HZ_CUST_ACCOUNT_SITE_V2PUB.create_cust_acct_site (
                                                p_init_msg_list => 'T',
                                                p_cust_acct_site_rec => pCustAcctSiteRec,
                                                x_cust_acct_site_id => oCustAcctSiteId,
                                                x_return_status => oStatus,
                                                x_msg_count =>  oMsgCount,
                                                x_msg_data => oMsgData);
                     if oStatus <> 'S' then
                        IF oMsgCount >1 THEN
                           FOR I IN 1..oMsgCount
                           LOOP
                              dbms_output.put_line(' Customer Site Record '||I||SubStr(FND_MSG_PUB.Get(p_encoded => FND_API.G_FALSE ), 1, 255));
                           END LOOP;
                        ELSE
                           dbms_output.put_line(' Customer Site Record '||oMsgData);
                        END IF;
                        RAISE e_validation_exception ;
                     else
                        IF NVL(pCustAcctId,-99) != oCustAccountId THEN
                           pBillToSiteUseId := null ;
                        END IF ;
                        IF c2.bill_to_flag = 'Y' THEN
                        --initialize the values
                        pCustAcctSiteUseRec := null ;
                        oStatus         :=null;
                        oMsgCount       :=null;
                        oMsgData        :=null;
                        whereami:=11;
                        pCustAcctSiteUseRec.site_use_code:='BILL_TO';
                        pCustAcctSiteUseRec.primary_flag := NVL(c2.primary_bill_to_flag,'N') ;
                        pCustAcctSiteUseRec.cust_acct_site_id:=oCustAcctSiteId;
                        pCustAcctSiteUseRec.created_by_module:='TCA_V1_API';
		        pcustomerprofile.profile_class_id:= p_profile_class_id ;
                        whereami:=12;
                        HZ_CUST_ACCOUNT_SITE_V2PUB.create_cust_site_use (
                                                   p_init_msg_list => 'T',
                                                   p_cust_site_use_rec => pCustAcctSiteUseRec,
                                                   p_customer_profile_rec => pCustomerProfile,
                                                   p_create_profile => 'T',
                                                   p_create_profile_amt =>'T',
                                                   x_site_use_id => oCustAcctSiteUseId,
                                                   x_return_status => oStatus,
                                                   x_msg_count => oMsgCount,
                                                   x_msg_data => oMsgData);
                        pBillToSiteUseId := oCustAcctSiteUseId ;
                        pCustAcctId := oCustAccountId ;
                        if oStatus <> 'S' then
                           IF oMsgCount >1 THEN
                              FOR I IN 1..oMsgCount
                              LOOP
                                 dbms_output.put_line('Customer BILL_TO Site Use Record '||I||SubStr(FND_MSG_PUB.Get(p_encoded => FND_API.G_FALSE ), 1, 255));
                              END LOOP;
                           ELSE
                              dbms_output.put_line('Customer BILL_TO Site Use Record '||oMsgData);
                           END IF;
                           RAISE e_validation_exception ;
                        else
                           p_proceed_flag := 'Y';
                        end if;
                        END IF ; -- Bill_to_flag
                        IF c2.Ship_to_flag = 'Y' THEN
                        --initialize the values
                        pCustAcctSiteUseRec := null ;
                        oStatus         :=null;
                        oMsgCount       :=null;
                        oMsgData        :=null;
                        whereami:=13;
                        pCustAcctSiteUseRec.site_use_code:='SHIP_TO';
                        pCustAcctSiteUseRec.primary_flag := NVL(c2.primary_ship_to_flag,'N') ;
                        pCustAcctSiteUseRec.cust_acct_site_id:=oCustAcctSiteId;
                        pCustAcctSiteUseRec.bill_to_site_use_id := pBillToSiteUseId;
                        pCustAcctSiteUseRec.created_by_module:='TCA_V1_API';
		        pcustomerprofile.profile_class_id:= p_profile_class_id ;
                        whereami:=14;
                        HZ_CUST_ACCOUNT_SITE_V2PUB.create_cust_site_use (
                                                   p_init_msg_list => 'T',
                                                   p_cust_site_use_rec => pCustAcctSiteUseRec,
                                                   p_customer_profile_rec => pCustomerProfile,
                                                   p_create_profile => 'T',
                                                   p_create_profile_amt =>'T',
                                                   x_site_use_id => oCustAcctSiteUseId,
                                                   x_return_status => oStatus,
                                                   x_msg_count => oMsgCount,
                                                   x_msg_data => oMsgData);
                        if oStatus <> 'S' then
                           IF oMsgCount >1 THEN
                              FOR I IN 1..oMsgCount
                              LOOP
                                 dbms_output.put_line('Customer SHIP_TO Site Use Record '||I||SubStr(FND_MSG_PUB.Get(p_encoded => FND_API.G_FALSE ), 1, 255));
                              END LOOP;
                           ELSE
                              dbms_output.put_line('Customer SHIP_TO Site Use Record '||oMsgData);
                           END IF;
                           RAISE e_validation_exception ;
                        else
                           p_proceed_flag := 'Y';
                        end if;
                        END IF ; -- ship_to_flag
                        --- Start of Contact creation
                        IF p_proceed_flag = 'Y' THEN
                           IF c2.bill_to_contact_lname IS NOT NULL OR c2.ship_to_contact_lname IS NOT NULL THEN
                           -- Person Creation
                           whereami:=15;
                           BEGIN
                              SELECT party_id
                                INTO oPpartyId
                                FROM hz_parties
                               WHERE party_type ='PERSON'
                                 AND upper(person_first_name) = upper(NVL(c2.bill_to_contact_fname, c2.ship_to_contact_fname))
                                 AND upper(person_last_name) = upper(NVL(c2.bill_to_contact_lname, c2.ship_to_contact_lname))
                                 AND rownum = 1 ;
                           EXCEPTION
                               WHEN no_data_found THEN
                                 -- Start Create Person
                                  oStatus         :=null;
                                  oMsgCount       :=null;
                                  oMsgData        :=null;
                                  whereami:=16;
                                  pPersonRec.person_first_name := NVL(c2.bill_to_contact_fname, c2.ship_to_contact_fname) ;
                                  pPersonRec.person_last_name := NVL(c2.bill_to_contact_lname, c2.ship_to_contact_lname) ;
                                  pPersonRec.created_by_module:='TCA_V1_API';
                                  whereami:=17;
                                  HZ_PARTY_V2PUB.create_person (
                                                 p_init_msg_list => 'T',
                                                 p_person_rec => pPersonRec,
                                                 x_return_status => oStatus,
                                                 x_msg_count => oMsgCount,
                                                 x_msg_data => oMsgData,
                                                 x_party_id => oPpartyId,
                                                 x_party_number => oPpartyNumber,
                                                 x_profile_id => oPprofileId);
                                  if oStatus <> 'S' then
                                     IF oMsgCount >1 THEN
                                        FOR I IN 1..oMsgCount
                                        LOOP
                                          dbms_output.put_line('Person Record '||I||SubStr(FND_MSG_PUB.Get(p_encoded => FND_API.G_FALSE ), 1, 255));
                                        END LOOP;
                                     ELSE
                                        dbms_output.put_line('Person Record '||oMsgData);
                                     END IF;
                                    p_proceed_flag := 'N';
                                    RAISE e_validation_exception ;
                                  else
                                    p_proceed_flag := 'Y';
                                  end if;
                           END ; -- Person creation End
                           IF p_proceed_flag = 'Y' THEN
                              -- Start Create Customer Site Contact
                             whereami:=18;
                             BEGIN
                                SELECT hr.relationship_id
                                      ,hr.party_id
                                      ,hoc.org_contact_id
                                  INTO oOcPartyRelId
                                      ,oOcPartyId
                                      ,oOcOrgContactId
                                  FROM hz_relationships hr,
                                       hz_org_contacts hoc
                                 WHERE hr.relationship_id = hoc.party_relationship_id
                                   AND subject_type = 'PERSON'
                                   AND subject_table_name = 'HZ_PARTIES'
                                   AND subject_id = oPpartyId
                                   AND object_type = 'ORGANIZATION'
                                   AND object_table_name = 'HZ_PARTIES'
                                   AND object_id = oPartyId
                                   AND relationship_code = 'CONTACT_OF'
                                   AND relationship_type = 'CONTACT' ;
                                 oStatus := 'S' ;
                             EXCEPTION
                                WHEN no_data_found THEN
                                   oStatus         :=null;
                                   oMsgCount       :=null;
                                   oMsgData        :=null;
                                   whereami:=19;
                                   pOrgContactRec.created_by_module := 'TCA_V1_API';
                                   -- pOrgContactRec.party_site_id := oPartySiteId ;
                                   --pOrgContactRec.department_code := 'ACCOUNTING';
                                   --pOrgContactRec.job_title := 'ACCOUNTS OFFICER';
                                   pOrgContactRec.decision_maker_flag := 'Y';
                                   --pOrgContactRec.job_title_code := 'APC';
                                   pOrgContactRec.party_rel_rec.subject_id := oPpartyId ;
                                   pOrgContactRec.party_rel_rec.subject_type := 'PERSON';
                                   pOrgContactRec.party_rel_rec.subject_table_name := 'HZ_PARTIES';
                                   pOrgContactRec.party_rel_rec.object_id := oPartyId ;
                                   pOrgContactRec.party_rel_rec.object_type := 'ORGANIZATION';
                                   pOrgContactRec.party_rel_rec.object_table_name := 'HZ_PARTIES';
                                   pOrgContactRec.party_rel_rec.relationship_code := 'CONTACT_OF';
                                   pOrgContactRec.party_rel_rec.relationship_type := 'CONTACT';
                                   pOrgContactRec.party_rel_rec.start_date := SYSDATE;
                                   whereami:=20;
                                   hz_party_contact_v2pub.create_org_contact (
                                                    p_init_msg_list    => 'T',
                                                    p_org_contact_rec  =>  pOrgContactRec ,
                                                    x_org_contact_id   =>  oOcOrgContactId ,
                                                    x_party_rel_id     =>  oOcPartyRelId ,
                                                    x_party_id         =>  oOcPartyId ,
                                                    x_party_number     =>  oOcPartyRelNumber ,
                                                    x_return_status    =>  oStatus,
                                                    x_msg_count        =>  oMsgCount,
                                                    x_msg_data         =>  oMsgData
                                                    ) ;
                                   if oStatus <> 'S' then
                                      IF oMsgCount >1 THEN
                                         FOR I IN 1..oMsgCount
                                         LOOP
                                            dbms_output.put_line('Org Contact '||I||SubStr(FND_MSG_PUB.Get(p_encoded => FND_API.G_FALSE ), 1, 255));
                                         END LOOP;
                                      ELSE
                                         dbms_output.put_line('Org Contact '||oMsgData);
                                      END IF;
                                      p_proceed_flag := 'N';
                                      RAISE e_validation_exception ;
                                   else
                                    -- Start Create Phone Contact Point
                                      IF c2.bill_to_contact_phone IS NOT NULL OR c2.ship_to_contact_phone IS NOT NULL THEN
                                         oStatus         :=null;
                                         oMsgCount       :=null;
                                         oMsgData        :=null;
                                         whereami:=21;
                                         pContactPointRec.contact_point_type := 'PHONE';
                                         pContactPointRec.owner_table_name := 'HZ_PARTIES';
                                         pContactPointRec.owner_table_id := oOcPartyId ;
                                         pContactPointRec.primary_flag := 'Y';
                                         pContactPointRec.contact_point_purpose := 'BUSINESS';
                                         --pPhoneRec.phone_area_code := '650';
                                         --pPhoneRec.phone_country_code := '1';
                                         pPhoneRec.phone_extension := c2.bill_to_contact_ph_ext ;
                                         pPhoneRec.phone_number := NVL(c2.bill_to_contact_phone,c2.ship_to_contact_phone) ;
                                         pPhoneRec.phone_line_type := 'GEN';
                                         pContactPointRec.created_by_module := 'TCA_V1_API' ;
                                         whereami:=22;
                                         hz_contact_point_v2pub.create_contact_point (
                                                         p_init_msg_list    => 'T',
                                                         p_contact_point_rec => pContactPointRec ,
                                                         p_edi_rec => pEdiRec ,
                                                         p_email_rec => pEmailRec ,
                                                         p_phone_rec => pPhoneRec ,
                                                         p_telex_rec => pTelexRec ,
                                                         p_web_rec => pWebRec ,
                                                         x_contact_point_id => oContactPointId ,
                                                         x_return_status    =>  oStatus,
                                                         x_msg_count        =>  oMsgCount,
                                                         x_msg_data         =>  oMsgData
                                                         ) ;
                                         if oStatus <> 'S' then
                                            IF oMsgCount >1 THEN
                                               FOR I IN 1..oMsgCount
                                               LOOP
                                                  dbms_output.put_line('Phone contact point '||I||SubStr(FND_MSG_PUB.Get(p_encoded => FND_API.G_FALSE ), 1, 255));
                                               END LOOP;
                                            ELSE
                                               dbms_output.put_line('Phone contact point '||oMsgData);
                                            END IF;
                                            p_proceed_flag := 'N';
                                            RAISE e_validation_exception ;
                                         end if ;
                                      END IF ; --contact point
                                      -- Start Create Fax Contact Point
                                      IF c2.bill_to_contact_fax IS NOT NULL THEN
                                         oStatus         :=null;
                                         oMsgCount       :=null;
                                         oMsgData        :=null;
                                         whereami:=23;
                                         pContactPointRec.contact_point_type := 'PHONE';
                                         pContactPointRec.owner_table_name := 'HZ_PARTIES';
                                         pContactPointRec.owner_table_id := oOcPartyId ;
                                         pContactPointRec.primary_flag := 'Y';
                                         pContactPointRec.contact_point_purpose := 'BUSINESS';
                                         pPhoneRec.phone_number := c2.bill_to_contact_fax ;
                                         pPhoneRec.phone_line_type := 'FAX';
                                         pContactPointRec.created_by_module := 'TCA_V1_API' ;
                                         whereami:=24;
                                         hz_contact_point_v2pub.create_contact_point (
                                                          p_init_msg_list    => 'T',
                                                          p_contact_point_rec => pContactPointRec ,
                                                          p_edi_rec => pEdiRec ,
                                                          p_email_rec => pEmailRec ,
                                                          p_phone_rec => pPhoneRec ,
                                                          p_telex_rec => pTelexRec ,
                                                          p_web_rec => pWebRec ,
                                                          x_contact_point_id => oContactPointId ,
                                                          x_return_status    =>  oStatus,
                                                          x_msg_count        =>  oMsgCount,
                                                          x_msg_data         =>  oMsgData
                                                          ) ;
                                         if oStatus <> 'S' then
                                            IF oMsgCount >1 THEN
                                               FOR I IN 1..oMsgCount
                                               LOOP
                                                  dbms_output.put_line('Fax Contact Point '||I||SubStr(FND_MSG_PUB.Get(p_encoded => FND_API.G_FALSE ), 1, 255));
                                               END LOOP;
                                            ELSE
                                               dbms_output.put_line('Fax Contact Point'||oMsgData);
                                            END IF;
                                            RAISE e_validation_exception ;
                                            p_proceed_flag := 'N';
                                         end if ;
                                      END IF ; -- Fax contact point
                                END IF ;
                             END ;
                             IF oStatus = 'S' THEN
                             -- Start Create customer Contact Role
                                oStatus         :=null;
                                oMsgCount       :=null;
                                oMsgData        :=null;
                                whereami:=25;
                                pCustAcctRoleRec.party_id := oOcPartyId ;
                                pCustAcctRoleRec.cust_account_id := oCustAccountId ;
                                pCustAcctRoleRec.cust_acct_site_id := oCustAcctSiteId ;
                                pCustAcctRoleRec.created_by_module := 'TCA_V1_API';
                                pCustAcctRoleRec.role_type := 'CONTACT' ;
                                whereami:=26;
                                HZ_CUST_ACCOUNT_ROLE_V2PUB.create_cust_account_role (
                                                      p_init_msg_list    => 'T',
                                                      p_cust_account_role_rec => pCustAcctRoleRec ,
                                                      x_cust_account_role_id =>  oCustAcctRoleId ,
                                                      x_return_status    =>  oStatus,
                                                      x_msg_count        =>  oMsgCount,
                                                      x_msg_data         =>  oMsgData
                                                      ) ;
                                if oStatus <> 'S' then
                                   IF oMsgCount >1 THEN
                                      FOR I IN 1..oMsgCount
                                      LOOP
                                         dbms_output.put_line('Cust Acct Role '||I||SubStr(FND_MSG_PUB.Get(p_encoded => FND_API.G_FALSE ), 1, 255));
                                      END LOOP;
                                   ELSE
                                      dbms_output.put_line('Cust Acct Role '||oMsgData);
                                   END IF;
                                   p_proceed_flag := 'N';
                                   RAISE e_validation_exception ;
                                else
                                     -- Start Attach role responsibility
                                      oStatus         :=null;
                                      oMsgCount       :=null;
                                      oMsgData        :=null;
                                      whereami:=27;
                                      IF c2.bill_to_contact_lname IS NOT NULL THEN
                                         pRoleResponsibilityRec.responsibility_type := 'BILL_TO' ;
                                      ELSIF c2.ship_to_contact_lname IS NOT NULL THEN
                                         pRoleResponsibilityRec.responsibility_type := 'SHIP_TO' ;
                                      END IF ;
                                      pRoleResponsibilityRec.cust_account_role_id := oCustAcctRoleId ;
                                      pRoleResponsibilityRec.created_by_module := 'TCA_V1_API' ;
                                      whereami:=28;
                                      HZ_CUST_ACCOUNT_ROLE_V2PUB.create_role_responsibility (
                                                           p_init_msg_list           =>  'T',
                                                           p_role_responsibility_rec => pRoleResponsibilityRec ,
                                                           x_responsibility_id       => oResponsibilityId ,
                                                           x_return_status           => oStatus ,
                                                           x_msg_count               => oMsgCount ,
                                                           x_msg_data                => oMsgData
                                                           ) ;
                                      if oStatus <> 'S' then
                                         IF oMsgCount >1 THEN
                                            FOR I IN 1..oMsgCount
                                            LOOP
                                               dbms_output.put_line('Role responsibility'||I||SubStr(FND_MSG_PUB.Get(p_encoded => FND_API.G_FALSE ), 1, 255));
                                            END LOOP;
                                         ELSE
                                            dbms_output.put_line('Role responsibility'||oMsgData);
                                         END IF;
                                         RAISE e_validation_exception ;
                                         p_proceed_flag := 'N';
                                      end if ; --Role responsibility
                                       --
                                end if ;
                             end if;	-- Cust Contact role process flag
                           p_proceed_flag := 'N';
                           END IF ; -- Bill_to_lname or ship_to_lname
                    end if ;
                        END IF ;  -- process flag
                        --- End of Contact Creation
                     end if; --cust acct site
                     -- Start create Contact point at Customer Site Telecommunication tab
                     IF (c2.bill_to_contact_phone IS NOT NULL AND c2.bill_to_contact_lname IS NULL)
                        OR ( c2.ship_to_contact_phone IS NOT NULL AND c2.ship_to_contact_lname IS NULL) THEN
                        oStatus         :=null;
                        oMsgCount       :=null;
                        oMsgData        :=null;
                        whereami:=29;
                        pContactPointRec := null;
                        pPhoneRec := null;
                        pContactPointRec.contact_point_type := 'PHONE';
                        pContactPointRec.owner_table_name := 'HZ_PARTY_SITES';
                        pContactPointRec.owner_table_id := oPartySiteId ;
                        pContactPointRec.primary_flag := NVL(c2.primary_bill_to_flag, c2.primary_ship_to_flag);
                        pContactPointRec.contact_point_purpose := 'BUSINESS';
                        --pPhoneRec.phone_area_code := '650';
                        --pPhoneRec.phone_country_code := '1';
                        pPhoneRec.phone_extension := c2.bill_to_contact_ph_ext ;
                        pPhoneRec.phone_number := NVL(c2.bill_to_contact_phone,c2.ship_to_contact_phone) ;
                        pPhoneRec.phone_line_type := 'GEN';
                        pContactPointRec.created_by_module := 'TCA_V1_API' ;
                        whereami:=30;
                        hz_contact_point_v2pub.create_contact_point (
                                               p_init_msg_list    => 'T',
                                               p_contact_point_rec => pContactPointRec ,
                                               p_phone_rec => pPhoneRec ,
                                               x_contact_point_id => oContactPointId ,
                                               x_return_status    =>  oStatus,
                                               x_msg_count        =>  oMsgCount,
                                               x_msg_data         =>  oMsgData
                                               ) ;
                        if oStatus <> 'S' then
                           IF oMsgCount >1 THEN
                              FOR I IN 1..oMsgCount
                              LOOP
                                 dbms_output.put_line('Phone contact point at Site '||I||SubStr(FND_MSG_PUB.Get(p_encoded => FND_API.G_FALSE ), 1, 255));
                              END LOOP;
                           ELSE
                              dbms_output.put_line('Phone contact point at Site '||oMsgData);
                           END IF;
                           RAISE e_validation_exception ;
                        end if ;
                     END IF ; --Phone contact point at Site
                     -- Start Create Fax Contact Point
                     IF c2.bill_to_contact_fax IS NOT NULL AND c2.bill_to_contact_lname IS NULL THEN
                        oStatus         :=null;
                        oMsgCount       :=null;
                        oMsgData        :=null;
                        whereami:=31;
                        pContactPointRec := null;
                        pPhoneRec := null;
                        pContactPointRec.contact_point_type := 'PHONE';
                        pContactPointRec.owner_table_name := 'HZ_PARTY_SITES';
                        pContactPointRec.owner_table_id := oPartySiteId ;
                        pContactPointRec.contact_point_purpose := 'BUSINESS';
                        pPhoneRec.phone_number := c2.bill_to_contact_fax ;
                        pPhoneRec.phone_line_type := 'FAX';
                        pContactPointRec.created_by_module := 'TCA_V1_API' ;
                        whereami:=32;
                        hz_contact_point_v2pub.create_contact_point (
                                               p_init_msg_list    => 'T',
                                               p_contact_point_rec => pContactPointRec ,
                                               p_phone_rec => pPhoneRec ,
                                               x_contact_point_id => oContactPointId ,
                                               x_return_status    =>  oStatus,
                                               x_msg_count        =>  oMsgCount,
                                               x_msg_data         =>  oMsgData
                                               ) ;
                        if oStatus <> 'S' then
                           IF oMsgCount >1 THEN
                              FOR I IN 1..oMsgCount
                              LOOP
                                 dbms_output.put_line('Fax Contact Point at Site'||I||SubStr(FND_MSG_PUB.Get(p_encoded => FND_API.G_FALSE ), 1, 255));
                              END LOOP;
                           ELSE
                              dbms_output.put_line('Fax Contact Point at Site'||oMsgData);
                           END IF;
                           RAISE e_validation_exception ;
                        end if ;
                     END IF ; -- Fax contact point at Site
                  end if; -- party site
               end if;	-- location
              END IF ;
            END LOOP;  --rec_cust_main
                        -- Start email contact point creation
                        IF C1.customer_email IS NOT NULL THEN
                           oStatus         :=null;
                           oMsgCount       :=null;
                           oMsgData        :=null;
                           whereami:=33;
                           pContactPointRec:=null;
                           pEdiRec         :=null;
                           pEmailRec       :=null;
                           pPhoneRec       :=null;
                           pTelexRec       :=null;
                           pWebRec         :=null;
                           pContactPointRec.contact_point_type := 'EMAIL';
                           pContactPointRec.owner_table_name := 'HZ_PARTIES';
                           pContactPointRec.owner_table_id := oPartyId ;
                           --pContactPointRec.primary_flag := 'Y';
                           pContactPointRec.contact_point_purpose := null;
                           pEmailRec.email_address :=  C1.customer_email ;
                           --pEmailRec.email_format :=  null ;
                           pContactPointRec.created_by_module := 'TCA_V1_API' ;
                           whereami:=34;
                           hz_contact_point_v2pub.create_contact_point (
                                               p_init_msg_list    => 'T',
                                               p_contact_point_rec => pContactPointRec ,
                                               p_edi_rec => pEdiRec ,
                                               p_email_rec => pEmailRec ,
                                               p_phone_rec => pPhoneRec ,
                                               p_telex_rec => pTelexRec ,
                                               p_web_rec => pWebRec ,
                                               x_contact_point_id => oContactPointId ,
                                               x_return_status    =>  oStatus,
                                               x_msg_count        =>  oMsgCount,
                                               x_msg_data         =>  oMsgData
                                                ) ;
                           if oStatus <> 'S' then
                              IF oMsgCount >1 THEN
                                 FOR I IN 1..oMsgCount
                                 LOOP
                                    dbms_output.put_line('email contact point '||I||SubStr(FND_MSG_PUB.Get(p_encoded => FND_API.G_FALSE ), 1, 255));
                                 END LOOP;
                              ELSE
                                 dbms_output.put_line('email contact point '||oMsgData);
                              END IF;
                              RAISE e_validation_exception ;
                           end if ;
                        END IF ; -- email contact point creation
                        -- Start Web (URL) contact point creation
                        IF C1.customer_url IS NOT NULL THEN
                           oStatus         :=null;
                           oMsgCount       :=null;
                           oMsgData        :=null;
                           pContactPointRec:=null;
                           pEdiRec         :=null;
                           pEmailRec       :=null;
                           pPhoneRec       :=null;
                           pTelexRec       :=null;
                           pWebRec         :=null;
                           whereami:=35;
                           pContactPointRec.contact_point_type := 'WEB';
                           pContactPointRec.owner_table_name := 'HZ_PARTIES';
                           pContactPointRec.owner_table_id := oPartyId ;
                           --pContactPointRec.primary_flag := 'Y';
                           pContactPointRec.contact_point_purpose := 'HOMEPAGE';
                           pWebRec.url := C1.customer_url ;
                           pWebRec.web_type := 'WEB';
                           pContactPointRec.created_by_module := 'TCA_V1_API' ;
                           whereami:=36;
                           hz_contact_point_v2pub.create_contact_point (
                                               p_init_msg_list    => 'T',
                                               p_contact_point_rec => pContactPointRec ,
                                               p_edi_rec => pEdiRec ,
                                               p_email_rec => pEmailRec ,
                                               p_phone_rec => pPhoneRec ,
                                               p_telex_rec => pTelexRec ,
                                               p_web_rec => pWebRec ,
                                               x_contact_point_id => oContactPointId ,
                                               x_return_status    =>  oStatus,
                                               x_msg_count        =>  oMsgCount,
                                               x_msg_data         =>  oMsgData
                                                ) ;
                           dbms_output.put_line('In contact success  '||p_proceed_flag||' '||oPpartyId||' '||oOcPartyId||' '||oPartyId );
                           if oStatus <> 'S' then
                              IF oMsgCount >1 THEN
                                 FOR I IN 1..oMsgCount
                                 LOOP
                                    dbms_output.put_line('Web URL contact point '||I||SubStr(FND_MSG_PUB.Get(p_encoded => FND_API.G_FALSE ), 1, 255));
                                 END LOOP;
                              ELSE
                                 dbms_output.put_line('Web URL contact point '||oMsgData);
                              END IF;
                              RAISE e_validation_exception ;
                           end if ;
                        END IF ; -- URL contact point creation
      End if; -- cust account
   end if; --Organization
END LOOP;

--COMMIT;
--dbms_output.put_line(' Customer Data creation is completed ');

EXCEPTION
    WHEN e_validation_exception THEN
       ROLLBACK;
       DBMS_OUTPUT.PUT_LINE('ERROR IN xxzen_CUSTOMER_INTERFACE PROCEDURE' || to_char(whereami));
    WHEN OTHERS THEN
       ROLLBACK;
       DBMS_OUTPUT.PUT_LINE('ERROR IN xxzen_CUSTOMER_INTERFACE PROCEDURE' || to_char(whereami));
END xxzen_customer_interface ;-- PROCEDURE END ;

END xxzen_customer_conversion ; -- PACKAGE BODY --
/
