create or replace package body nexmo_pkg as
------------------------------------------------------
-- Package: NEXMO_PKG
-- Author:	Christina Moore, @cmoore_sp
-- 
-- This package is an API for a few of the features found
-- at Nexmo.com for using SMS (text messaging).
-- 
-- tabs or spaces: Tabs \t
--
-- Revision History
-- 0.1		05FEB2017
--
------------------------------------------------------



	------------------------------------------------------
	-- You will need to establish your own account with 
	-- Nexmo. The KEY and SECRET and SENDER get pasted below
	------------------------------------------------------
	g_key					constant varchar2(255)	:= '**CHANGE_ME**';
	g_secret			constant varchar2(255)	:= '**CHANGE_ME**';
	g_sender			constant varchar2(20)		:= '**CHANGE_ME**'; 

	------------------------------------------------------
	-- The calls are made via HTTPS so you will need your own
	-- Wallet Path and Password
	-- 12c Hint Wallet Path, you'll need a final \ as shown below
	-- 
	-- g_wallet_path	constant varchar2(255)	:= 'file:d:\app\oracle\admin\orcl\wallet\'
	--
	-- 12c Hint regarding wallet, you should not store the customer's SSL cert,
	-- but you must store the root and intermediate cert in your wallet.
	------------------------------------------------------
	g_wallet_path	constant varchar2(255)	:= 'file:d:\app\oracle\admin\orcl\wallet\';
	g_wallet_pwd	constant varchar2(255) 	:= '**CHANGE_ME**';

	g_sms_uri			varchar2(255) := 'https://rest.nexmo.com/sms/json?';	
	g_verify_uri	varchar2(255) := 'https://api.nexmo.com/verify/';	
	amp				constant varchar2(1)		:= chr(38);
	crlf			constant	varchar2(2) 	:= chr(10) || chr(13);

	/* Table definition
		create sequence nexmo_sms_response_seq;
		create table nexmo_sms_response (
			response_pk				number not null primary key,
			status						varchar2(255),
			message_id				varchar2(255),
			message_to				varchar2(255),
			message_text			varchar2(1000),
			client_ref				varchar2(255),
			remaining_balance	number,
			message_price			number,
			message_network		varchar2(255),
			error_text				varchar2(1000),
			code							varchar2(20),
			ip_address				varchar2(20),
			purpose						varchar2(20),
			created_timestamp	timestamp
		);
		
		create or replace editionable trigger nexmo_sms_response_trig
		before insert or update on nexmo_sms_response for each row
		begin
			if inserting then
				:new.response_pk := nexmo_sms_response_seq.NEXTVAL;
				:new.created_timestamp :=CURRENT_TIMESTAMP;
			end if;
		end nexmo_sms_response_trig;
		/
		
	*/
procedure sms_ok (
	p_sms						in varchar2,
	p_procedure			in varchar2,
	p_northamerican	in varchar2 default 'Y'
	) 
------------------------------------------------
-- P_SMS is the phone number
-- P_PROCEDURE is the name of the calling procedure, used for error traps
-- P_NORTHAMERICAN (Y/N) identifies if the phone number must be 11 characters long
------------------------------------------------
as
	l_na_length		number := 11;
------------------------------------------------
-- Procedure	SMS_OK
-- Author:	Christina Moore, @cmoore_sp
-- 
-- Tests if SMS number matches specifications
-- If it does not, an error is raised
--
-- Revision History
-- 0.1		02FEB2017		cmoore
--
------------------------------------------------------
begin
	if p_sms is null then
		raise_application_error (-20000,
			'Phone number is blank(null) in nexmo_pkg.'||P_PROCEDURE); 
	end if; -- sms null
	if regexp_like( p_sms, '^[0-9]*$') then
		null;
	else
		raise_application_error (-20000,
			'Phone number contains non-numeric characters in nexmo_pkg.'||P_PROCEDURE); 
	end if; -- test if all are numbers
	if p_northamerican like 'Y%' then
		if length(p_sms) = l_na_length then
			null;
		else 
			raise_application_error (-20000,
				'Phone number is not 11 digits long in nexmo_pkg.'||P_PROCEDURE); 
		end if; -- length is 11 for North American numbers
	end if; -- check length
end sms_ok;

function msg_ok (
	p_msg						in varchar2,
	p_procedure			in varchar2,
	p_max_length		in number default 160
	) return varchar2
------------------------------------------------
-- P_MSG is the text message
-- P_PROCEDURE is the name of the calling procedure, used for error traps
-- P_MAX_LENGTH (160) is the maximum length of text. Text may be 918 char 
--			long, but they will then be broken into chunks of 153 char
------------------------------------------------
as
------------------------------------------------
-- Function	MSG_OK
-- Author:	Christina Moore, @cmoore_sp
-- 
-- Tests if a text message matches specifications
-- If it does not, an error is raised
-- If it does, it formats it as required by NEXMO
--
-- Revision History
-- 0.1		02FEB2017		cmoore
--
------------------------------------------------------
begin
	if p_msg is null then
		raise_application_error (-20000,
			'Message is blank(null) in nexmo_pkg.'||P_PROCEDURE); 
	end if; -- msg null
	if length(p_msg) > p_max_length then
		raise_application_error (-20000,
			'Text message exceeds max length in nexmo_pkg.'||P_PROCEDURE); 
	end if; -- message length less than maximum
	
	-- replace spaces with plus sign and return 
	return utl_url.unescape(replace(p_msg, ' ', '+'));
end msg_ok;

function get_balance return number
as
------------------------------------------------
-- Function	GET_BALANCE
-- Author:	Christina Moore, @cmoore_sp
-- 
-- Fetches the balance of a NEXMO account
--
-- Revision History
-- 0.1		02FEB2017		cmoore
--
------------------------------------------------------
	l_url						varchar2(255);
	l_balance 			number;
	l_return				clob;
	l_values				apex_json.t_values;
	l_paths					apex_t_varchar2;

begin
	
	-- structure the URL
	l_url := 'https://rest.nexmo.com/account/get-balance?' ||
			'api_key=' 			|| g_key 				|| amp ||
			'api_secret=' 	|| g_secret;
	
	l_return := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
			 p_url              => l_url
			,p_http_method      => 'GET'
			,p_wallet_path			=> g_wallet_path
			,p_wallet_pwd				=> g_wallet_pwd
			);
dbms_output.put_line(l_return);

	-- test for an error, 
	-- if JSON first character is a { 
	-- if html, first character is <
	if substr(l_return,1,1) <> '{' then
		-- capture the HTML as an error 
		-- post the error for research
		raise_application_error (-20000,
			'NEXMO HTML Error ' || l_return || ' in nexmo_pkg.get_balance'); 
	end if; -- error returned from REST request
		
	-- parse the JSON data 
	apex_json.parse (
		p_values => l_values,
		p_source => l_return
		);	

	-- capture the JSON data into Oracle fields
	l_balance := nvl(
		apex_json.get_varchar2(
			p_values => l_values, 
			p_path => 'value'
		),0);
	return l_balance;
end get_balance;
	
procedure send_sms (
	p_sms						in varchar2,
	p_msg						in varchar2,
	p_client_ref		in varchar2 default null,
	p_northamerican	in varchar2 default 'Y'
	)
------------------------------------------------
-- P_SMS is phone number - just digits, no paren, dash, etc. 
-- P_msg is text message
-- P_CLIENT_REF is a reference code that will be tracked in the response/billing 
--			table. You might use this to link each SMS with an application or a client
--			Recommendation - 1 WORD ONLY!
-- P_NORTHAMERICAN (Y/N) identifies if the phone number must be 11 characters long
------------------------------------------------	
as
------------------------------------------------
-- Function	MSG_OK
-- Author:	Christina Moore, @cmoore_sp
-- 
-- Tests if a text message matches specifications
-- If it does not, an error is raised
-- If it does, it formats it as required by NEXMO
--
-- Revision History
-- 0.1		02FEB2017		cmoore
--
------------------------------------------------------
	l_url						varchar2(255);
	l_text					varchar2(255);
	l_return				clob;
	l_message_count	number;
	l_temp					varchar2(255);
	l_values				apex_json.t_values;
	l_paths					apex_t_varchar2;
	r_response			nexmo_sms_response%ROWTYPE;
	l_response_pk		number;
begin
	-- validate the parameters
	sms_ok(p_sms,'send_sms','Y');
	l_text := msg_ok(p_msg,'send_sms');

	-- structure the URL
	l_url := g_sms_uri 	||
			'api_key=' 			|| g_key || amp ||
			'api_secret=' 	|| g_secret || amp ||
			'to=' 					|| p_sms || amp ||
			'from=' 				|| g_sender || amp ||
			'text=' 				|| l_text ;
	if p_client_ref is not null then
		l_url := l_url		|| amp ||
			'client-ref='		|| p_client_ref;
	end if; -- client reference is not null
	
	l_return := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
			 p_url              => l_url
			,p_http_method      => 'GET'
			,p_wallet_path			=> g_wallet_path
			,p_wallet_pwd				=> g_wallet_pwd
			);

	-- test for an error, 
	-- if JSON first character is a { 
	-- if html, first character is <
	if substr(l_return,1,1) <> '{' then
		-- capture the HTML as an error 
		r_response.error_text := substr(l_return,1,1000);
		-- post the error for research
		insert into nexmo_sms_response (
			error_text
		) values (
			r_response.error_text
		) returning response_pk into l_response_pk;
		commit;
		raise_application_error (-20000,
			'NEXMO HTML Error with response_pk: ' || trim(to_char(l_response_pk)) || ' in nexmo_pkg.send_sms'); 
	end if; -- error returned from REST request
		
	-- I can't explain this but... the Oracle JSON parser does not like dashes in field names
	-- And Nexmo deliberately put dashes in their field names (vs XML which does not)
	l_return := replace(l_return, 'message-id', 'messageId');
	l_return := replace(l_return, 'client-ref', 'clientRef');
	l_return := replace(l_return, 'remaining-balance', 'remainingBalance');
	l_return := replace(l_return, 'message-price', 'messagePrice');
	l_return := replace(l_return, 'error-text', 'errorText');

	-- parse the JSON data 
	apex_json.parse (
		p_values => l_values,
		p_source => l_return
		);	

	-- how many JSON records?
	l_message_count := APEX_JSON.GET_COUNT(
		p_path      => 'messages',
		p_values    => l_values
		);
	l_message_count := nvl(l_message_count,0);

	-- if there was at least 1 message, spin through the responses
	if nvl(l_message_count,0) <> 0 then
		for json_row in 1 .. l_message_count loop
		
			r_response.message_text := p_msg;
			r_response.purpose 			:= 'sms';
			-- capture the JSON data into Oracle fields
			r_response.status :=
				apex_json.get_varchar2(
					p_values => l_values, 
					p_path => 'messages[' || trim(to_char(json_row)) ||'].status'
				);
			r_response.message_id :=
				apex_json.get_varchar2(
					p_values => l_values, 
					p_path => 'messages[' || trim(to_char(json_row)) ||'].messageId'
				);
			r_response.message_to :=
				apex_json.get_varchar2(
					p_values => l_values, 
					p_path => 'messages[' || trim(to_char(json_row)) ||'].to'
				);				
			r_response.client_ref :=
				apex_json.get_varchar2(
					p_values => l_values, 
					p_path => 'messages[' || trim(to_char(json_row)) ||'].clientRef'
				);

			l_temp :=
				apex_json.get_varchar2(
					p_values => l_values, 
					p_path => 'messages[' || trim(to_char(json_row)) ||'].remainingBalance'
				);

			r_response.remaining_balance := to_number(nvl(l_temp,0));

			l_temp :=
				apex_json.get_varchar2(
					p_values => l_values, 
					p_path => 'messages[' || trim(to_char(json_row)) ||'].messagePrice'
				);
			r_response.message_price := to_number(nvl(l_temp,0));
			
			r_response.message_network :=
				apex_json.get_varchar2(
					p_values => l_values, 
					p_path => 'messages[' || trim(to_char(json_row)) ||'].network'
				);	
			r_response.error_text :=
				apex_json.get_varchar2(
					p_values => l_values, 
					p_path => 'messages[' || trim(to_char(json_row)) ||'].errorText'
				);			
			-- post the response to the oracle table
			insert into nexmo_sms_response values r_response;
			commit; -- need the commit to prevent the rollback if there is an error
			-- status <> 0 means that there is an error message within the JSON data
			if r_response.status <> '0' then
				raise_application_error (-20000,
					'NEXMO Error: ' || r_response.error_text || ' to #' || r_response.message_to || ' in nexmo_pkg.send_sms'); 
			end if;
		end loop; -- loop through messages
	end if; -- message count
end send_sms;

function verify_code_check (
	p_response_pk		in number,
	p_code					in varchar2,
	p_ip_address		in varchar2 default null
	) return varchar2
------------------------------------------------
-- P_RESPONSE_PK is the primary key of the Oracle table that references the verification
-- P_CODE is the 4 digit code provided by the user
-- P_IP_ADDRESS is the IP address of the user. This is optional
------------------------------------------------	
as
------------------------------------------------
-- Procedure	VERIFY_CODE_CHECK
-- Author:	Christina Moore, @cmoore_sp
-- 
-- After the function VERIFY_SMS triggers the 4 digit code
-- to be sent to the phone, this routine confirms that the 
-- 4 digit code matches.  
-- 
--
-- Revision History
-- 0.1		02FEB2017		cmoore
--
------------------------------------------------------
	l_url						varchar2(255);
	l_return				clob;
	l_select_count	number;
	l_message_id		varchar2(100);
	l_response_pk		number;
	l_values				apex_json.t_values;
	l_paths					apex_t_varchar2;
	l_status				varchar2(10);
	l_success				varchar2(10) := 'FAIL';
	r_response			nexmo_sms_response%ROWTYPE;
begin
	-- validate the parameters
	if p_response_pk is not null then
		select count(*) into l_select_count
			from nexmo_sms_response
			where response_pk = p_response_pk;
	end if; -- p_response_pk valid?
	if nvl(l_select_count,0) = 0 then
		raise_application_error (-20000,
			'The response primary key in nexmo_pkg.verify_code_check is invalid or null'); 
	end if;
	select 
			message_id,
			status
		into 
			l_message_id,
			l_status
		from nexmo_sms_response
		where response_pk = p_response_pk;
--	if l_status = '0' then
--		raise_application_error (-20000,
--			'The MFA code has already been used'); 	
--	end if; -- code has been used and verified
	
	-- structure the URL
	l_url := g_verify_uri 	|| 'check/json?' ||
			'api_key=' 			|| g_key 				|| amp ||
			'api_secret=' 	|| g_secret 		|| amp ||
			'request_id=' 	|| l_message_id || amp ||
			'code='					|| p_code ;
	-- if an ip address is provide append it to the URL
	if p_ip_address is not null then
		l_url := l_url || amp ||
			'ip_address='		|| p_ip_address;
	end if; -- IP Address is not null
	
	l_return := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
			 p_url              => l_url
			,p_http_method      => 'GET'
			,p_wallet_path			=> g_wallet_path
			,p_wallet_pwd				=> g_wallet_pwd
			);

	-- test for an error, 
	-- if JSON first character is a { 
	-- if html, first character is <
	if substr(l_return,1,1) <> '{' then
		-- capture the HTML as an error 
		r_response.error_text := substr(l_return,1,1000);
		-- post the error for research
		insert into nexmo_sms_response (
			error_text
		) values (
			r_response.error_text
		) returning response_pk into l_response_pk;
		commit;
		raise_application_error (-20000,
			'NEXMO HTML Error with response_pk: ' || trim(to_char(l_response_pk)) || ' in nexmo_pkg.verify_code_check'); 
	end if; -- error returned from REST request
		
	-- parse the JSON data 
	apex_json.parse (
		p_values => l_values,
		p_source => l_return
		);	

	-- capture the JSON data into Oracle fields
	r_response.status :=
		apex_json.get_varchar2(
			p_values => l_values, 
			p_path => 'status'
		);
	r_response.message_price :=
		apex_json.get_varchar2(
			p_values => l_values, 
			p_path => 'price'
		);
	r_response.error_text :=
		apex_json.get_varchar2(
			p_values => l_values, 
			p_path => 'error_text'
		);		
	-- post the response in the same record as the request that was made
	update nexmo_sms_response set
		status = r_response.status,
		message_price = r_response.message_price,
		error_text = r_response.error_text
	where response_pk = p_response_pk;
	commit; -- need the commit to prevent the rollback if there is an error
	-- status <> 0 means that there is an error message within the JSON data
	if r_response.status <> '0' then
		raise_application_error (-20000,
			'NEXMO Error: ' || r_response.error_text || ' to #' || r_response.message_to || ' in nexmo_pkg.verify_code_check'); 
	else
		l_success := 'PASS';
	end if;
	return l_success;
end verify_code_check;

function verify_sms (
	p_sms						in varchar2,
	p_brand					in varchar2 default null,
	p_northamerican	in varchar2 default 'Y'
	) return number
------------------------------------------------
-- P_SMS is phone number - just digits, no paren, dash, etc. 
-- P_BRAND is application name or reference 
-- P_NORTHAMERICAN (Y/N) identifies if the phone number must be 11 characters long
-- Return - the primary key for the response
------------------------------------------------	
as
------------------------------------------------
-- Function	MSG_OK
-- Author:	Christina Moore, @cmoore_sp
-- 
-- The routine causes NEXMO to send a 4 digit code to the cell phone.
-- A voice call will also be made if there is sufficient delay. The voice call
-- reads the 4 digit code to the listener.
-- 
-- This is the first of a two step process. The user must then enter the code
-- into an application. A second routine must be called to submit the verification
-- code. The code is not handed over. With the API, you pass a code and their system
-- tells you if it is valid.
--
-- The second part of this verify_code_check.
--
-- Revision History
-- 0.1		02FEB2017		cmoore
--
------------------------------------------------------
	l_url						varchar2(255);
	l_return				clob;
	l_temp					varchar2(255);
	l_values				apex_json.t_values;
	l_paths					apex_t_varchar2;
	r_response			nexmo_sms_response%ROWTYPE;
	l_response_pk		number;
begin
	-- validate the parameters
	sms_ok(p_sms,'verify_sms','Y');

	-- structure the URL
	l_url := g_verify_uri 	|| 'json?' ||
			'api_key=' 			|| g_key || amp ||
			'api_secret=' 	|| g_secret || amp ||
			'number=' 			|| p_sms || amp ||
			'brand=' 				|| p_brand;
	
	l_return := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
			 p_url              => l_url
			,p_http_method      => 'GET'
			,p_wallet_path			=> g_wallet_path
			,p_wallet_pwd				=> g_wallet_pwd
			);

	-- test for an error, 
	-- if JSON first character is a { 
	-- if html, first character is <
	if substr(l_return,1,1) <> '{' then
		-- capture the HTML as an error 
		r_response.error_text := substr(l_return,1,1000);
		-- post the error for research
		insert into nexmo_sms_response (
			error_text
		) values (
			r_response.error_text
		) returning response_pk into l_response_pk;
		commit;
		raise_application_error (-20000,
			'NEXMO HTML Error with response_pk: ' || trim(to_char(l_response_pk)) || ' in nexmo_pkg.verify_sms'); 
	end if; -- error returned from REST request
		
	-- parse the JSON data 
	apex_json.parse (
		p_values => l_values,
		p_source => l_return
		);	

	r_response.purpose	:= 'MFA'; -- multi-factor authentication
	-- capture the JSON data into Oracle fields
	r_response.status :=
		apex_json.get_varchar2(
			p_values => l_values, 
			p_path => 'status'
		);
	r_response.message_id :=
		apex_json.get_varchar2(
			p_values => l_values, 
			p_path => 'request_id'
		);
		
	-- post the response to the oracle table
	insert into nexmo_sms_response (
		status,
		message_id,
		purpose
	) values (
		r_response.status,
		r_response.message_id,
		r_response.purpose
	) return response_pk into l_response_pk;
	commit; -- need the commit to prevent the rollback if there is an error
	-- status <> 0 means that there is an error message within the JSON data
	if r_response.status <> '0' then
		raise_application_error (-20000,
			'NEXMO Error: ' || r_response.error_text || ' to #' || r_response.message_to || ' in nexmo_pkg.verify_sms'); 
	end if;
	return l_response_pk;
end verify_sms;

end nexmo_pkg;