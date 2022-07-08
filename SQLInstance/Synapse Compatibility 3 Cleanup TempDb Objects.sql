USE [tempdb]
GO
drop table dbo.LinkedServers
go
drop proc [spLoadLinkedServers]
go
drop proc [spPrintLongSql]
go
/****** Object:  StoredProcedure [dbo].[spLoadVolumes]     ******/
DROP PROCEDURE [dbo].[spLoadVolumes]
GO
/****** Object:  StoredProcedure [dbo].[spLoadTopWait]     ******/
DROP PROCEDURE [dbo].[spLoadTopWait]
GO
/****** Object:  StoredProcedure [dbo].[spLoadTopSql]     ******/
DROP PROCEDURE [dbo].[spLoadTopSql]
GO
/****** Object:  StoredProcedure [dbo].[spLoadServices]     ******/
DROP PROCEDURE [dbo].[spLoadServices]
GO
/****** Object:  StoredProcedure [dbo].[spLoadServers]     ******/
DROP PROCEDURE [dbo].[spLoadServers]
GO
/****** Object:  StoredProcedure [dbo].[spLoadSequences]     ******/
DROP PROCEDURE [dbo].[spLoadSequences]
GO

/****** Object:  StoredProcedure [dbo].[spLoadJobSteps]     ******/
DROP PROCEDURE [dbo].[spLoadJobSteps]
GO

/****** Object:  StoredProcedure [dbo].[spLoadJobs]     ******/
DROP PROCEDURE [dbo].[spLoadJobs]
GO
/****** Object:  StoredProcedure [dbo].[spLoadIndexUsage]     ******/
DROP PROCEDURE [dbo].[spLoadIndexUsage]
GO

/****** Object:  StoredProcedure [dbo].[spLoadDatabases]     ******/
DROP PROCEDURE [dbo].[spLoadDatabases]
GO
/****** Object:  StoredProcedure [dbo].[spLoadDataBaseObjects]     ******/
DROP PROCEDURE [dbo].[spLoadDataBaseObjects]
GO
/****** Object:  StoredProcedure [dbo].[spLoadDataBaseObjectColums]     ******/
DROP PROCEDURE [dbo].[spLoadDataBaseObjectColums]
GO
/****** Object:  StoredProcedure [dbo].[spLoadDataBaseFiles]     ******/
DROP PROCEDURE [dbo].[spLoadDataBaseFiles]
GO
/****** Object:  StoredProcedure [dbo].[spLoadClusterNodes]     ******/
DROP PROCEDURE [dbo].[spLoadClusterNodes]
GO
/****** Object:  StoredProcedure [dbo].[spLoadAvailabilityGroups]     ******/
DROP PROCEDURE [dbo].[spLoadAvailabilityGroups]
GO
/****** Object:  StoredProcedure [dbo].[spLoad]     ******/
DROP PROCEDURE [dbo].[spLoad]
GO
/****** Object:  StoredProcedure [dbo].[spExecCommand]     ******/
DROP PROCEDURE [dbo].[spExecCommand]
GO
/****** Object:  StoredProcedure [dbo].[spExec]     ******/
DROP PROCEDURE [dbo].[spExec]

GO
/****** Object:  StoredProcedure [dbo].[spCleanup]     ******/
DROP PROCEDURE [dbo].[spCleanup]
GO

GO
/****** Object:  Table [dbo].[Sequences]     ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Sequences]') AND type in (N'U'))
DROP TABLE [dbo].[Sequences]
GO
/****** Object:  Table [dbo].[JobSteps]     ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[JobSteps]') AND type in (N'U'))
DROP TABLE [dbo].[JobSteps]
GO

GO

GO
/****** Object:  View [dbo].[vwServers]     ******/
DROP VIEW [dbo].[vwServers]
GO

/****** Object:  Table [dbo].[Services]     ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Services]') AND type in (N'U'))
DROP TABLE [dbo].[Services]
GO

/****** Object:  View [dbo].[vwVolumes]     ******/
DROP VIEW [dbo].[vwVolumes]
GO
/****** Object:  Table [dbo].[Volumes]     ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Volumes]') AND type in (N'U'))
DROP TABLE [dbo].[Volumes]
GO
/****** Object:  View [dbo].[vwTopWait]     ******/
DROP VIEW [dbo].[vwTopWait]
GO
/****** Object:  Table [dbo].[TopWait]     ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TopWait]') AND type in (N'U'))
DROP TABLE [dbo].[TopWait]
GO
/****** Object:  View [dbo].[vwTopSql]     ******/
DROP VIEW [dbo].[vwTopSql]
GO
/****** Object:  Table [dbo].[TopSql]     ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TopSql]') AND type in (N'U'))
DROP TABLE [dbo].[TopSql]
GO

/****** Object:  View [dbo].[vwJobs]     ******/
DROP VIEW [dbo].[vwJobs]
GO
/****** Object:  View [dbo].[vwClusterNodes]     ******/
DROP VIEW [dbo].[vwClusterNodes]
GO
/****** Object:  Table [dbo].[ClusterNodes]     ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ClusterNodes]') AND type in (N'U'))
DROP TABLE [dbo].[ClusterNodes]
GO
/****** Object:  View [dbo].[vwAvailabilityGroups]     ******/
DROP VIEW [dbo].[vwAvailabilityGroups]
GO
/****** Object:  Table [dbo].[AvailabilityGroups]     ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AvailabilityGroups]') AND type in (N'U'))
DROP TABLE [dbo].[AvailabilityGroups]
GO
/****** Object:  View [dbo].[vwDatabaseObjectColumns]     ******/
DROP VIEW [dbo].[vwDatabaseObjectColumns]
GO
/****** Object:  View [dbo].[vwDatabaseObjects]     ******/
DROP VIEW [dbo].[vwDatabaseObjects]
GO
/****** Object:  Table [dbo].[DatabaseObjectColumns]     ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DatabaseObjectColumns]') AND type in (N'U'))
DROP TABLE [dbo].[DatabaseObjectColumns]
GO
/****** Object:  View [dbo].[vwDatabaseFiles]     ******/
DROP VIEW [dbo].[vwDatabaseFiles]
GO
/****** Object:  View [dbo].[vwDatabases]     ******/
DROP VIEW [dbo].[vwDatabases]
GO
/****** Object:  Table [dbo].[DatabaseFiles]     ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DatabaseFiles]') AND type in (N'U'))
DROP TABLE [dbo].[DatabaseFiles]
GO
/****** Object:  View [dbo].[vwIndexUsage]     ******/
DROP VIEW [dbo].[vwIndexUsage]
GO
/****** Object:  Table [dbo].[IndexUsage]     ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[IndexUsage]') AND type in (N'U'))
DROP TABLE [dbo].[IndexUsage]
GO
/****** Object:  Table [dbo].[DatabaseObjects]     ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DatabaseObjects]') AND type in (N'U'))
DROP TABLE [dbo].[DatabaseObjects]
GO
/****** Object:  Table [dbo].[Databases]     ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Databases]') AND type in (N'U'))
DROP TABLE [dbo].[Databases]
GO

/****** Object:  Table [dbo].[Jobs]     ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Jobs]') AND type in (N'U'))
DROP TABLE [dbo].[Jobs]
GO
/****** Object:  Table [dbo].[Servers]     ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Servers]') AND type in (N'U'))
DROP TABLE [dbo].[Servers]
GO

/****** Object:  UserDefinedFunction [dbo].[udf_schedule_description]     ******/
DROP FUNCTION [dbo].[udf_schedule_description]
GO
/****** Object:  UserDefinedFunction [dbo].[RegexMatch]     ******/
DROP FUNCTION [dbo].[RegexMatch]
GO
/****** Object:  UserDefinedFunction [dbo].[InStringCount]     ******/
DROP FUNCTION [dbo].[InStringCount]
GO
/****** Object:  UserDefinedFunction [dbo].[fnNullVal]     ******/
DROP FUNCTION [dbo].[fnNullVal]
GO
drop table [ExecErrors]
go
drop proc [spReturn]
go
drop table [SysConfigurations]
go
drop proc spLoadSysConfigurations
go
if OBJECT_ID('spImport') is not null
	drop proc spImport
go
if OBJECT_ID('spCleanup') is not null
	drop proc spCleanup
go
drop proc [spLoadIncompatibilities]
go

drop table [dbo].[Synapse_ComputedColumn]
drop table [dbo].[Synapse_IncompatibleColumn]
drop table [dbo].[Synapse_IncompatibleRoutine]
drop table [dbo].[Synapse_IncompatibleRoutineType]
drop table [dbo].[Synapse_InvalidDefaults]
drop table [dbo].[Synapse_LargeTextColumn]
drop table [dbo].[Synapse_XDatabaseRoutine]
drop table [dbo].[Synapse_XServerRoutine]
