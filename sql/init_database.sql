/*
 * Create database and schemas
 * 
 * Script Purpose: 
 * This script creates a new databae named 'datawarehouse'. If this database
 * already exists then the script removes the database and then recreates the database.
 * Additionally, the script sets up three schemas within the database named
 * 'bronze', 'silver' and 'gold'
 * 
 * WARNING:
 * Upon running this script the data in the already existing database 'datawarehouse'
 * will get deleted. Proceed with caution and ensure you have proper backups before running this
 * script. 
 */

--Delete Database warehouse if it exists already
drop database if exists datawarehouse with (force);

--Create new database named datawarehouse
create database datawarehouse;

--switch database to the database named 'datawarehouse'
 
--Create schemas for different layers 
create schema bronze;
create schema silver;
create schema gold;
