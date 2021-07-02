---
title: MYSQL数据库的基本操作
tags:
  - MYSQL
  - 数据库
categories:
  - MYSQL
date: 2021-07-03 00:01:27
---
# MYSQL数据库的基本操作

## 1、root登录mysql

```sql
mysql -uroot -p
Enter password: *****
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 8
Server version: 8.0.25 MySQL Community Server - GPL

Copyright (c) 2000, 2021, Oracle and/or its affiliates.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.
```

## 2、查看数据库

```sql
mysql> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
| sys                |
+--------------------+
```

## 3、查看表

```sql
mysql> use mysql
Database changed
mysql> show tables;
+------------------------------------------------------+
| Tables_in_mysql                                      |
+------------------------------------------------------+
| columns_priv                                         |
| component                                            |
| db                                                   |
| default_roles                                        |
| engine_cost                                          |
| func                                                 |
| general_log                                          |
| global_grants                                        |
| gtid_executed                                        |
| help_category                                        |
| help_keyword                                         |
| help_relation                                        |
| help_topic                                           |
| innodb_index_stats                                   |
| innodb_table_stats                                   |
| password_history                                     |
| plugin                                               |
| procs_priv                                           |
| proxies_priv                                         |
| replication_asynchronous_connection_failover         |
| replication_asynchronous_connection_failover_managed |
| role_edges                                           |
| server_cost                                          |
| servers                                              |
| slave_master_info                                    |
| slave_relay_log_info                                 |
| slave_worker_info                                    |
| slow_log                                             |
| tables_priv                                          |
| time_zone                                            |
| time_zone_leap_second                                |
| time_zone_name                                       |
| time_zone_transition                                 |
| time_zone_transition_type                            |
| user                                                 |
+------------------------------------------------------+
```

## 4、退出数据库

```sql
mysql> exit;
Bye
```

## 5、创建数据库

```sql
mysql> create database mydb01;
```

## 6、创建表

```sql
mysql> create table employee(id int, name varchar(30), sex int, birthday date, salary double, entry_date date, resume text);
```

## 7、创建表数据

```sql
insert into employee values(1,'韩信',1,'1997-07-07',15000,'2020-02-02','突进刺客');
insert into employee(id,name,sex,birthday,salary,entry_date,resume) values(2,'兰陵王',1,'1996-06-06',12000,'2020-01-01','脆皮刺客');
insert into employee(id,name,sex,birthday,salary,entry_date,resume) values(3,'亚瑟',1,'1000-01-01',8000,'2020-10-01','前排坦克');
```

## 查看表信息

```sql
mysql> desc employee;
+------------+-------------+------+-----+---------+-------+
| Field      | Type        | Null | Key | Default | Extra |
+------------+-------------+------+-----+---------+-------+
| id         | int         | YES  |     | NULL    |       |
| name       | varchar(30) | YES  |     | NULL    |       |
| sex        | int         | YES  |     | NULL    |       |
| birthday   | date        | YES  |     | NULL    |       |
| salary     | double      | YES  |     | NULL    |       |
| entry_date | date        | YES  |     | NULL    |       |
| resume     | text        | YES  |     | NULL    |       |
+------------+-------------+------+-----+---------+-------+
```

## 8、查看表数据

```sql
mysql> select * from employee;
+------+--------+------+------------+--------+------------+----------+
| id   | name   | sex  | birthday   | salary | entry_date | resume   |
+------+--------+------+------------+--------+------------+----------+
|    1 | 韩信   |    1 | 1997-07-07 |  15000 | 2020-02-02 | 突进刺客 |
|    2 | 兰陵王 |    1 | 1996-06-06 |  12000 | 2020-01-01 | 脆皮刺客 |
|    3 | 亚瑟   |    1 | 1000-01-01 |   8000 | 2020-10-01 | 前排坦克 |
+------+--------+------+------------+--------+------------+----------+
```

## 修改某个项的内容

```sql
mysql> update employee set resume='偷家小贼' where id=1;
Query OK, 1 row affected (0.01 sec)

mysql> select * from employee;
+------+--------+------+------------+--------+------------+----------+
| id   | name   | sex  | birthday   | salary | entry_date | resume   |
+------+--------+------+------------+--------+------------+----------+
|    1 | 韩信   |    1 | 1997-07-07 |  15000 | 2020-02-02 | 偷家小贼 |
|    2 | 兰陵王 |    1 | 1996-06-06 |  12000 | 2020-01-01 | 脆皮刺客 |
|    3 | 亚瑟   |    1 | 1000-01-01 |   8000 | 2020-10-01 | 前排坦克 |
+------+--------+------+------------+--------+------------+----------+
```

# example

```sql
create table students(id int, name varchar(20), chinese int, english int, math int);
insert into students(id, name, chinese, english, math) values(1, '黄真', 80, 85, 90);
insert into students(id, name, chinese, english, math) values(2, '归辛树', 90, 95, 95);
insert into students(id, name, chinese, english, math) values(3, '李寻欢', 80, 96, 96);
insert into students(id, name, chinese, english, math) values(4, '叶开', 81, 97, 85);
insert into students(id, name, chinese, english, math) values(5, '袁承志', 85, 84, 90);
insert into students(id, name, chinese, english, math) values(6, '何红药', 92, 85, 87);
insert into students(id, name, chinese, english, math) values(7, '何铁手', 75, 81, 80);
insert into students(id, name, chinese, english, math) values(8, '夏雪宜', 77, 80, 79);
insert into students(id, name, chinese, english, math) values(9, '任我行', 95, 85, 85);
insert into students(id, name, chinese, english, math) values(10, '岳不群', 94, 85, 84);


增加一列：
alter table students add class_id int;

id <= 5 为1班， id > 5 为2班
update students set class_id=1 where id <= 5;

select ceil(id/5),id from students;

update students set class_id=ceil(id/5);

求平均
select avg(english),class_id from students group by class_id;

求和
select sum(chinese+math+english), class_id from students group by class_id;
+---------------------------+----------+
| sum(chinese+math+english) | class_id |
+---------------------------+----------+
|                      1329 |        1 |
|                      1264 |        2 |
+---------------------------+----------+

找到总分大于1300的
select sum(chinese+english+math), class_id from students group by class_id having sum(chinese+english+math)>1300;
+---------------------------+----------+
| sum(chinese+english+math) | class_id |
+---------------------------+----------+
|                      1329 |        1 |
+---------------------------+----------+

查看当前时间
select now() from dual;
+---------------------+
| now()               |
+---------------------+
| 2021-06-19 14:44:07 |
+---------------------+


select now()-1,now(),now()+1 from dual;
+----------------+---------------------+----------------+
| now()-1        | now()               | now()+1        |
+----------------+---------------------+----------------+
| 20210619164648 | 2021-06-19 16:46:49 | 20210619164650 |
+----------------+---------------------+----------------+


求今天、昨天、明天
select date_add(now(), interval -1 day), now(), date_add(now(), interval 1 day) from dual;
+----------------------------------+---------------------+---------------------------------+
| date_add(now(), interval -1 day) | now()               | date_add(now(), interval 1 day) |
+----------------------------------+---------------------+---------------------------------+
| 2021-06-18 16:53:37              | 2021-06-19 16:53:37 | 2021-06-20 16:53:37             |
+----------------------------------+---------------------+---------------------------------+
1 row in set (0.07 sec)

select addtime(now(),'0:1:0'),now() from dual;
+------------------------+---------------------+
| addtime(now(),'0:1:0') | now()               |
+------------------------+---------------------+
| 2021-06-19 17:00:34    | 2021-06-19 16:59:34 |
+------------------------+---------------------+

字符串
select concat('hello ', 'mysql', 'yyds', '123.') from dual;
+-------------------------------------------+
| concat('hello ', 'mysql', 'yyds', '123.') |
+-------------------------------------------+
| hello mysqlyyds123.                       |
+-------------------------------------------+
1 row in set (0.00 sec)
```
