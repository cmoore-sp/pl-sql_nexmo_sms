# PL/SQL Interface for Nexmo SMS / 2FA
This includes a PL/SQL package (specifications & body) for a series of tools related to Nexmo.com. We have also included
a functioning, but simple Oracle APEX application. The APEX application is written in APEX 5.1 and will not likely be
compatible with APEX 5.0.

The use of this tool does require the following:
 1. You MUST have an account with Nexmo.com. You can get a demo account for free.
 2. You MUST put your own Oracle Wallet Path and Wallet password into the packages and compile them (G_WALLET_PATH and G_WALLET_PWD)
 3. You MUST manually install the Root and Intermediate SSL certs for nexmo.com in your wallet
  - ROOT: Digicert Global Root CA, v3, valid through 09NOV2031
  - Intermediate: Digicert SHA2 Secure Server CA, valid thorugh 08MAR2013
 4. If you are on Oracle 12c, DO NOT install the SSL cert for *.nexmo.com
 5. You'll need to create the table that is in the package body. It is in the commented out section. 
 6. You'll need to put in your own G_KEY and G_SECRET at the top of the package body.

The features within the package are:
 - Send SMS text message from PL/SQL
 - Do a two-factor authentication
 - Check the balance of your account
 
 This was released in early February 2016. I will endeavour to maintain this.
@cmoore_sp
