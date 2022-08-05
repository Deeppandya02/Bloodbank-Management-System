CREATE DATABASE bloodbank;
use bloodbank;

-- *********Create Tables*********
CREATE TABLE IF NOT EXISTS Aadhar_Details (
  Aadhar_No char(16) NOT NULL,
  First_Name varchar(20) NOT NULL,
  Last_Name varchar(20) NOT NULL,
  Address varchar(200) NOT NULL,
  Date_Of_Birth date NOT NULL,
  Gender char(1) NOT NULL,
  PRIMARY KEY (Aadhar_No)
);

CREATE TABLE IF NOT EXISTS Member_Details (
  Aadhar_No char(16) NOT NULL,
  Member_ID INT(11) AUTO_INCREMENT NOT NULL,  
  Blood_Group varchar(5) NOT NULL,
  Contact_No char(10) CHECK(LENGTH(Contact_No)=10),
  Email_ID varchar(30) CHECK(Email_ID LIKE '%_@_%._%'),
  PRIMARY KEY (Member_ID),
  CONSTRAINT FK FOREIGN KEY (Aadhar_No) REFERENCES Aadhar_Details(Aadhar_No) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Blood_Bank_Centre (
  Centre_ID varchar(6) NOT NULL,
  Centre_Name varchar(30) NOT NULL,
  District varchar(15) NOT NULL,
  State varchar(15) NOT NULL,
  PRIMARY KEY (Centre_ID)
);

CREATE TABLE IF NOT EXISTS Availability (
	Centre_ID varchar(6),
    Blood_Group varchar(5) NOT NULL,
    Amount int DEFAULT 0,
    PRIMARY KEY (Centre_ID, Blood_Group),
    CONSTRAINT FK_Availability FOREIGN KEY (Centre_ID) REFERENCES Blood_Bank_Centre(Centre_ID) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Donor_Details (
  Member_ID int,
  Donation_Centre varchar(6) NOT NULL,
  timsetamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  Donation_Date date,
  Haemoglobin_Status float,
  Physical_Status bool DEFAULT false,
  PRIMARY KEY (Member_ID, Donation_Centre),
  KEY CK (Member_ID, Donation_Date)
);
CREATE TABLE Receipient_Details (
  Member_ID int,
  Collection_Centre varchar(6) NOT NULL,
  State varchar(15) NOT NULL,
  Quantity_Required int,
  Request_Date date,
  Received_Blood_Group varchar(5),
  PRIMARY KEY (Member_ID, Request_Date), 
  CONSTRAINT FK_Receipient FOREIGN KEY (Member_ID) REFERENCES Member_Details(Member_ID)
);

CREATE TABLE IF NOT EXISTS Matching (
  Requested_Blood varchar(5),
  Received_Blood varchar(5)
);

-- Procedures

DELIMITER $$
CREATE PROCEDURE check_member(IN aadhar char(16), IN first varchar(20), IN last varchar(20), IN dob date, IN gen char(1), OUT status int)
READS SQL DATA
BEGIN
START TRANSACTION;
SELECT count(*) into status 
from ( select * from aadhar_details where aadhar_No = aadhar AND First_Name = first AND Last_Name = last AND Date_Of_Birth = dob AND Gender = gen)as t;
COMMIT;
END $$
DEliMITER ;

DELIMITER $$
CREATE PROCEDURE insert_member (IN aadhar char(16), IN first varchar(20), IN last varchar(20), IN dob date, IN gen char(1), IN blood_grp varchar(5), IN contact char(10), IN email varchar(30))
READS SQL DATA
BEGIN
START TRANSACTION;
CALL check_member(aadhar, first, last,dob,gen,@s);
IF @s THEN
insert into member_details(Aadhar_No, Blood_Group, Contact_No, Email_ID) values(aadhar, blood_grp,contact,email);
END IF;
COMMIT;
END $$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE insert_donor (IN member int, IN centre varchar(6), IN DOD date)
BEGIN
START TRANSACTION;
insert into donor_details(Member_ID, Donation_Centre,Donation_Date) values(member, centre, DOD);
COMMIT;
END $$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE update_donor(IN member int, IN DOD date)
BEGIN
START TRANSACTION;
SELECT Physical_Status into @s FROM Donor_Details WHERE Member_ID = member AND Donation_Date = DOD;
IF @s = false
THEN
	UPDATE Donor_Details SET Physical_Status = true where Member_ID = member AND Donation_Date = DOD;
	SELECT Donation_Centre into @c FROM Donor_Details WHERE Member_ID = member AND Donation_Date = DOD;
    CALL fetch_blood_grp(member,@g);
	CALL update_availability (@c, @g, 300);
END IF;
COMMIT;
END $$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE insert_centre (IN centre varchar(6),IN name varchar(30),IN dist varchar(15), IN state varchar(15))
BEGIN
START TRANSACTION;
insert into blood_bank_centre values(centre, name, dist,state);
CALL insert_avail(centre, 'A+ve');
CALL insert_avail(centre, 'A-ve');
CALL insert_avail(centre, 'B+ve');
CALL insert_avail(centre, 'B-ve');
CALL insert_avail(centre, 'AB+ve');
CALL insert_avail(centre, 'AB-ve');
CALL insert_avail(centre, 'O+ve');
CALL insert_avail(centre, 'O-ve');
COMMIT;
END $$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE insert_avail(IN centre varchar(6), IN grp varchar(5))
BEGIN
START TRANSACTION;
insert into availability values (centre, grp, Default);
COMMIT;
END $$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE find_match (IN member int,IN st varchar(15), IN amt int)
BEGIN
START TRANSACTION;
CALL fetch_blood_grp(member,@g);
SELECT DISTINCT Centre_Name FROM blood_bank_centre WHERE Centre_ID IN (Select Centre_ID FROM availability where Amount >= amt AND 
Blood_Group IN (SELECT Received_Blood FROM matching where Requested_Blood = @g) AND 
Centre_ID IN (SELECT Centre_ID FROM blood_bank_centre where State = st));
COMMIT;
END $$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE select_centre( IN Centre varchar(30), IN member int, IN st varchar(15), IN req_date date, IN amt int)
BEGIN
START TRANSACTION;
CALL fetch_blood_grp(member,@g);
SELECT Centre_ID into @id FROM blood_bank_centre where Centre_Name = Centre;
-- Assuumption that User selects only from the drop down menu. i.e. We don't have to check if the centre has blood or not
 SELECT Blood_Group into @bl FROM availability WHERE Blood_Group IN (SELECT Received_Blood FROM matching where Requested_Blood = @g) AND Centre_ID = @id AND Amount >= amt LIMIT 1;
 UPDATE availability SET Amount = Amount - amt WHERE Centre_ID = @id AND Blood_Group = @bl;
 INSERT into Receipient_Details values (member, @id, st, amt, req_date, @bl);
COMMIT;
END $$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE fetch_blood_grp(IN member int, OUT grp varchar(5))
BEGIN
START TRANSACTION;
select Blood_Group into grp from member_details where Member_ID = member;
COMMIt;
END $$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE update_availability(IN centre varchar(6), IN grp varchar(5), IN amt int)
BEGIN
START TRANSACTION;
UPDATE availability SET Amount = Amount + amt WHERE Centre_ID = centre AND Blood_Group = grp;
COMMIT;
END $$
DELIMITER ;

-- Sample Aadhar Database

insert into Aadhar_Details values('7894785678127823','Farah','Akthar','Meera Road','2015/06/7','F');
insert into Aadhar_Details values('7894785678127824','Ruchika','Sarkar','South point','1979/07/09','F');
insert into Aadhar_Details values('7894785678127825','Sanam','Puri','Sitla Bari Lane','2014/1/04','M');
insert into Aadhar_Details values('7894785678127826','Emran','Shah','Hokishe Sema Road','2000/02/05','M');
insert into Aadhar_Details values('7894785678127827','Aakshay','Khan','Sematilla','1999/03/06','M');
insert into Aadhar_Details values('7894785678127828','Archaj','Jain','Town Ship Area','2003/04/12','M');
insert into Aadhar_Details values('7894785678127829','AryaVeer Singh','Chauhan','Vinod Tailoring Complex','1980/1/1','M');
insert into Aadhar_Details values('7894785678127830','Ruchi','Bhattacharjee','South Mall Society','1999/05/21','F');
insert into Aadhar_Details values('7894785678127831','Shaz','Furniture Wala','South point','1977/5/09','M');
insert into Aadhar_Details values('7894785678127832','Bhuvnesh','Bamboo','Lhomithy Colony','2000/12/27','F');

-- Insert Member Details

CALL insert_member('7894785678127823','B+ve','8837365354','farah@gmail.com');
CALL insert_member('7894785678127824','A+ve','7894561230','ruchika@hotmail.com');
CALL insert_member('7894785678127825','AB+ve','9456874236','sanam@gmail.com');

-- Insert New Centre

CALL insert_centre('NL01','Dimapur Blood Centre','Dimapur','Nagaland');
CALL insert_centre('RJ02','Bhilwara Blood Centre','Bhilwara','Rajasthan');
CALL insert_centre('RJ01','Pilani Blood Centre','Pilani','Rajasthan');

-- Insert Donor Details

CALL insert_donor(4, 'NL01', '2022-01-01');
CALL insert_donor(5, 'RJ02', '2022-04-20');
CALL insert_donor(6, 'RJ02', '2022-05-01');

--  Find all members

DELIMITER $$
CREATE PROCEDURE find_members()
READS SQL DATA
BEGIN
SELECT * FROM member_details;
END $$
DELIMITER ;

-- Find all members with particular blood group
DELIMITER $$
CREATE PROCEDURE membersWithGroup(IN grp varchar(5))
READS SQL DATA
BEGIN
SELECT * FROM member_details WHERE Blood_Group = grp;
END $$
DELIMITER ;

-- Find Member_ID from Aadhar_No

DELIMITER $$
CREATE PROCEDURE MemberWithAadhar(IN aadhar char(16), OUT mem int)
READS SQL DATA
BEGIN
SELECT * FROM member_details WHERE Member_ID = mem;
END $$
DELIMITER ;

-- Find all instances of donations of particular member

DELIMITER $$
CREATE PROCEDURE donation_count(IN member int)
READS SQL DATA
BEGIN
SELECT * FROM donor_details WHERE Member_ID =  member AND Physical_Status = true;
END $$
DELIMITER ;

-- Return count of donations grouped by Donation Centre

DELIMITER $$
CREATE PROCEDURE CountDonationCentre(IN centre varchar(6))
READS SQL DATA
BEGIN
SELECT Donation_Centre, count(*) FROM donor_details WHERE Physical_Status = true GROUP BY Donation_Centre;
END $$
DELIMITER ;

-- Return date with highest donations

DELIMITER $$
CREATE PROCEDURE HighestDonationDate()
READS SQL DATA
BEGIN
SELECT Donation_Date, MAX(COUNT(*)) FROM donor_details WHERE Physical_Status=true GROUP BY Donation_Date;
END $$
DELIMITER ;

-- Return all centre in a state

DELIMITER $$
CREATE PROCEDURE CentreWithState(IN st varchar(15))
READS SQL DATA
BEGIN
SELECT * FROM blood_bank_centre WHERE State = st;
END $$
DELIMITER ;

-- Find all instances of Receiving Blood by a particular member

DELIMITER $$
CREATE PROCEDURE receipient(IN member int)
READS SQL DATA
BEGIN
SELECT * FROM receipient_details WHERE Member_ID =  member;
END $$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE CountReceiveCentre(IN centre varchar(6))
READS SQL DATA
BEGIN
SELECT Collection_Centre, count(*) FROM receipient_details GROUP BY Collection_Centre;
END $$
DELIMITER ;