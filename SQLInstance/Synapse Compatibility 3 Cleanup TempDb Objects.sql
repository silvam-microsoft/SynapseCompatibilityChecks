USE [tempdb]
GO
drop table dbo.LinkedServers
go
drop proc [spLoadLinkedServers]
go
drop proc [spPrintLongSql]
go
DROP PROCEDURE [dbo].[spLoadVolumes]
GO
DROP PROCEDURE [dbo].[spLoadTopWait]
GO
DROP PROCEDURE [dbo].[spLoadTopSql]
GO
DROP PROCEDURE [dbo].[spLoadServices]
GO
DROP PROCEDURE [dbo].[spLoadServers]
GO
DROP PROCEDURE [dbo].[spLoadSequences]
GO
DROP PROCEDURE [dbo].[spLoadJobSteps]
GO
DROP PROCEDURE [dbo].[spLoadJobs]
GO
DROP PROCEDURE [dbo].[spLoadIndexUsage]
GO
DROP PROCEDURE [dbo].[spLoadDatabases]
GO
DROP PROCEDURE [dbo].[spLoadDataBaseObjects]
GO
DROP PROCEDURE [dbo].[spLoadDataBaseObjectColums]
GO
DROP PROCEDURE [dbo].[spLoadDataBaseFiles]
GO
DROP PROCEDURE [dbo].[spLoadClusterNodes]
GO
DROP PROCEDURE [dbo].[spLoadAvailabilityGroups]
GO
DROP PROCEDURE [dbo].[spLoad]
GO
DROP PROCEDURE [dbo].[spExecCommand]
GO

DROP PROCEDURE [dbo].[spExec]

GO
DROP PROCEDURE [dbo].[spCleanup]
GO

GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Sequences]') AND type in (N'U'))
DROP TABLE [dbo].[Sequences]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[JobSteps]') AND type in (N'U'))
DROP TABLE [dbo].[JobSteps]
GO

DROP VIEW [dbo].[vwServers]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Services]') AND type in (N'U'))
DROP TABLE [dbo].[Services]
GO

DROP VIEW [dbo].[vwVolumes]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Volumes]') AND type in (N'U'))
DROP TABLE [dbo].[Volumes]
GO
DROP VIEW [dbo].[vwTopWait]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TopWait]') AND type in (N'U'))
DROP TABLE [dbo].[TopWait]
GO
DROP VIEW [dbo].[vwTopSql]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TopSql]') AND type in (N'U'))
DROP TABLE [dbo].[TopSql]
GO

DROP VIEW [dbo].[vwJobs]
GO
DROP VIEW [dbo].[vwClusterNodes]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ClusterNodes]') AND type in (N'U'))
DROP TABLE [dbo].[ClusterNodes]
GO
DROP VIEW [dbo].[vwAvailabilityGroups]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AvailabilityGroups]') AND type in (N'U'))
DROP TABLE [dbo].[AvailabilityGroups]
GO
DROP VIEW [dbo].[vwDatabaseObjectColumns]
GO
DROP VIEW [dbo].[vwDatabaseObjects]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DatabaseObjectColumns]') AND type in (N'U'))
DROP TABLE [dbo].[DatabaseObjectColumns]
GO
DROP VIEW [dbo].[vwDatabaseFiles]
GO
DROP VIEW [dbo].[vwDatabases]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DatabaseFiles]') AND type in (N'U'))
DROP TABLE [dbo].[DatabaseFiles]
GO
DROP VIEW [dbo].[vwIndexUsage]
GO
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
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Jobs]') AND type in (N'U'))
DROP TABLE [dbo].[Jobs]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Servers]') AND type in (N'U'))
DROP TABLE [dbo].[Servers]
GO

DROP FUNCTION [dbo].[udf_schedule_description]
GO
DROP FUNCTION [dbo].[RegexMatch]
GO
DROP FUNCTION [dbo].[InStringCount]
GO
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
go
drop table [dbo].[Synapse_IncompatibleColumn]
go
drop table [dbo].[Synapse_IncompatibleRoutine]
go
drop table [dbo].[Synapse_IncompatibleRoutineType]
go
drop table [dbo].[Synapse_InvalidDefaults]
go
drop table [dbo].[Synapse_LargeTextColumn]
go
drop table [dbo].[Synapse_XDatabaseRoutine]
go
drop table [dbo].[Synapse_XServerRoutine]
go

