create or replace package nexmo_pkg as
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

function get_balance return number;

procedure send_sms (
	p_sms						in varchar2,
	p_msg						in varchar2,
	p_client_ref		in varchar2 default null,
	p_northamerican	in varchar2 default 'Y'
	);

function verify_code_check (
	p_response_pk		in number,
	p_code					in varchar2,
	p_ip_address		in varchar2 default null
	) return varchar2;
	
function verify_sms (
	p_sms						in varchar2,
	p_brand					in varchar2 default null,
	p_northamerican	in varchar2 default 'Y'
	) return number;
	
end nexmo_pkg;