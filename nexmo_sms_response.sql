-- Table definition
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
