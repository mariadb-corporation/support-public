select count(PRIVILEGE_TYPE) into @PRIVCOUNT  from information_schema.USER_PRIVILEGES where GRANTEE=CONCAT('''',REPLACE(CURRENT_USER(),'@','''@'''),'''') and PRIVILEGE_TYPE in ('RELOAD','PROCESS','LOCK TABLES','BINLOG MONITOR');
select PRIVILEGE_TYPE as PRIVILEGES_GRANTED from information_schema.USER_PRIVILEGES where GRANTEE=CONCAT('''',REPLACE(CURRENT_USER(),'@','''@'''),'''') and PRIVILEGE_TYPE in ('RELOAD','PROCESS','LOCK TABLES','BINLOG MONITOR');

delimiter //
begin not atomic
  if @PRIVCOUNT=4 then 
    select CONCAT('''',REPLACE(CURRENT_USER(),'@','''@'''),''' has the 4 necessary privileges.') as NOTE;
  else
    select CONCAT('''',REPLACE(CURRENT_USER(),'@','''@'''),''' needs 4 privileges: RELOAD, PROCESS, LOCK TABLES, and BINLOG MONITOR.') as NOTE;
  end if;
end;
//
delimiter ;
