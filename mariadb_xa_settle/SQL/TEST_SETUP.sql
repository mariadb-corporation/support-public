-- DISTRIBUTED WITH mariadb_xa_settle by Edward Stoever for MariaDB Support
--  TEST_SETUP

create schema if not exists test_xa; 
use test_xa;

CREATE TABLE IF NOT EXISTS `xa_table` (
  `col1` int(11) NOT NULL AUTO_INCREMENT,
  `col2` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`col1`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


xa start '$ATR1', '$ATR2', $ATR3;

insert into test_xa.xa_table (col2) values (concat('I ',trim(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(substr(concat(md5(rand()),md5(rand()),md5(rand())),1,70),0,' '),1,' '),2,'m'),3,'q'),4,'r'),5,'v'),6,'w'),7,'j'),8,'p'),9,' '),'  ',' '),'  ',' ')),'.'));

xa end '$ATR1', '$ATR2', $ATR3;

xa prepare '$ATR1', '$ATR2', $ATR3;