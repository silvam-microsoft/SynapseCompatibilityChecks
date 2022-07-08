USE [tempdb]
GO
/****** Object:  StoredProcedure [dbo].[spPrintLongSql]    Script Date: 2/26/2021 9:13:24 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spPrintLongSql]( @string nvarchar(max) )
AS
SET NOCOUNT ON
 
set @string = rtrim( @string )
 
declare @cr char(1), @lf char(1)
set @cr = char(13)
set @lf = char(10)
 
declare @len int, @cr_index int, @lf_index int, @crlf_index int, @has_cr_and_lf bit, @left nvarchar(4000), @reverse nvarchar(4000)
set @len = 4000
 
while ( len( @string ) > @len )
begin
   set @left = left( @string, @len )
   set @reverse = reverse( @left )
   set @cr_index = @len - charindex( @cr, @reverse ) + 1
   set @lf_index = @len - charindex( @lf, @reverse ) + 1
   set @crlf_index = case when @cr_index < @lf_index then @cr_index else @lf_index end
   set @has_cr_and_lf = case when @cr_index < @len and @lf_index < @len then 1 else 0 end
   print left( @string, @crlf_index - 1 )
   set @string = right( @string, len( @string ) - @crlf_index - @has_cr_and_lf )
end
 
print @string
GO

CREATE TABLE [dbo].[ExecErrors](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[dt] [datetime] NULL,
	[message] [varchar](255) NULL,
	[command] [varchar](max) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE [dbo].[ExecErrors] ADD  DEFAULT (getdate()) FOR [dt]
GO


CREATE proc [dbo].[spExec] (@sql varchar(max), @debug bit = 0, @exec bit = 1, @raiserror bit=0)
as
begin
	begin try
		if @exec = 1
			exec (@sql)
		if @debug = 1
		begin
			if len(@sql) < 8000
				print @sql
			else 
				exec dbo.spPrintLongSql @sql
			--print 'GO'			
		end
	end try
	begin catch
		declare @error varchar(255), @severity int, @state int
		select @error = ERROR_MESSAGE()
			, @severity = ERROR_SEVERITY()
			, @state = ERROR_STATE()
		
		if len(@sql) < 8000
			print @sql
		else 
			exec dbo.spPrintLongSql @sql
		
		insert into ExecErrors (message, command) values (@error, @sql)

		if @raiserror = 1
			raiserror (@error, @severity, @state)
		else 
			print error_message()
	end catch
end



GO
create function [dbo].[fnNullVal] (@Type varchar(100) )
returns varchar(100)
as
begin 
	declare @NullVal varchar(100)

	select @NullVal = case  when @Type LIKE '%char%' then ''''''
							when @Type LIKE '%text%' then ''''''
							when @Type LIKE 'decimal%' then '0'
							when @Type LIKE 'numeric%' then '0'
							when @Type LIKE 'varbinary%' then '0x'
							when @Type in ('tinyint','smallint','float','money','int','bit','smallmoney','bigint') then '0'
							when @Type in ('uniqueidentifier') then '''00000000-0000-0000-0000-000000000000'''
							when @Type in ('datetime', 'date','smalldatetime') then '''01/01/1999'''
							else ''''''
							--TODO: image, datetime, varbinary
						end 
	return(@NullVal)
end		
GO
/****** Object:  UserDefinedFunction [dbo].[InStringCount]    Script Date: 2/26/2021 8:58:12 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[InStringCount](
    @searchString nvarchar(max),
    @searchTerm nvarchar(max)
)
RETURNS INT
AS
BEGIN
    return (LEN(@searchString)-LEN(REPLACE(@searchString,@searchTerm,'')))/LEN(@searchTerm)
END
GO
/****** Object:  UserDefinedFunction [dbo].[RegexMatch]    Script Date: 2/26/2021 8:58:12 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[RegexMatch]
    (
      @pattern VARCHAR(2000),
      @matchstring VARCHAR(MAX)--Varchar(8000) got SQL Server 2000
    )
RETURNS INT
AS BEGIN
    DECLARE @objRegexExp INT,
        @objErrorObject INT,
        @strErrorMessage VARCHAR(255),
        @hr INT,
        @match BIT
    
    
    SELECT  @strErrorMessage = 'creating a regex object'
    EXEC @hr= sp_OACreate 'VBScript.RegExp', @objRegexExp OUT
    IF @hr = 0
        EXEC @hr= sp_OASetProperty @objRegexExp, 'Pattern', @pattern
        --Specifying a case-insensitive match
    IF @hr = 0
        EXEC @hr= sp_OASetProperty @objRegexExp, 'IgnoreCase', 1
        --Doing a Test'
    IF @hr = 0
        EXEC @hr= sp_OAMethod @objRegexExp, 'Test', @match OUT, @matchstring

    IF @hr <> 0
        BEGIN
            RETURN NULL
        END
    EXEC sp_OADestroy @objRegexExp
    RETURN @match
   END
GO
/****** Object:  UserDefinedFunction [dbo].[udf_schedule_description]    Script Date: 2/26/2021 8:58:12 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[udf_schedule_description] (@freq_type INT ,
 @freq_interval INT ,
 @freq_subday_type INT ,
 @freq_subday_interval INT ,
 @freq_relative_interval INT ,
 @freq_recurrence_factor INT ,
 @active_start_date INT ,
 @active_end_date INT,
 @active_start_time INT ,
 @active_end_time INT ) 
RETURNS NVARCHAR(255) AS 
BEGIN
DECLARE @schedule_description NVARCHAR(255)
DECLARE @loop INT
DECLARE @idle_cpu_percent INT
DECLARE @idle_cpu_duration INT

IF (@freq_type = 0x1) -- OneTime
 BEGIN
 SELECT @schedule_description = N'Once on ' + CONVERT(NVARCHAR, @active_start_date) + N' at ' + CONVERT(NVARCHAR, cast((@active_start_time / 10000) as varchar(10)) + ':' + right('00' + cast((@active_start_time % 10000) / 100 as varchar(10)),2))
 RETURN @schedule_description
 END
IF (@freq_type = 0x4) -- Daily
 BEGIN
 SELECT @schedule_description = N'Every day '
 END
IF (@freq_type = 0x8) -- Weekly
 BEGIN
 SELECT @schedule_description = N'Every ' + CONVERT(NVARCHAR, @freq_recurrence_factor) + N' week(s) on '
 SELECT @loop = 1
 WHILE (@loop <= 7)
 BEGIN
 IF (@freq_interval & POWER(2, @loop - 1) = POWER(2, @loop - 1))
 SELECT @schedule_description = @schedule_description + DATENAME(dw, N'1996120' + CONVERT(NVARCHAR, @loop)) + N', '
 SELECT @loop = @loop + 1
 END
 IF (RIGHT(@schedule_description, 2) = N', ')
 SELECT @schedule_description = SUBSTRING(@schedule_description, 1, (DATALENGTH(@schedule_description) / 2) - 2) + N' '
 END
IF (@freq_type = 0x10) -- Monthly
 BEGIN
 SELECT @schedule_description = N'Every ' + CONVERT(NVARCHAR, @freq_recurrence_factor) + N' months(s) on day ' + CONVERT(NVARCHAR, @freq_interval) + N' of that month '
 END
IF (@freq_type = 0x20) -- Monthly Relative
 BEGIN
 SELECT @schedule_description = N'Every ' + CONVERT(NVARCHAR, @freq_recurrence_factor) + N' months(s) on the '
 SELECT @schedule_description = @schedule_description +
 CASE @freq_relative_interval
 WHEN 0x01 THEN N'first '
 WHEN 0x02 THEN N'second '
 WHEN 0x04 THEN N'third '
 WHEN 0x08 THEN N'fourth '
 WHEN 0x10 THEN N'last '
 END +
 CASE
 WHEN (@freq_interval > 00)
 AND (@freq_interval < 08) THEN DATENAME(dw, N'1996120' + CONVERT(NVARCHAR, @freq_interval))
 WHEN (@freq_interval = 08) THEN N'day'
 WHEN (@freq_interval = 09) THEN N'week day'
 WHEN (@freq_interval = 10) THEN N'weekend day'
 END + N' of that month '
 END
IF (@freq_type = 0x40) -- AutoStart
 BEGIN
 SELECT @schedule_description = FORMATMESSAGE(14579)
 RETURN @schedule_description
 END
IF (@freq_type = 0x80) -- OnIdle
 BEGIN
 EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
 N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
 N'IdleCPUPercent',
 @idle_cpu_percent OUTPUT,
 N'no_output'
 EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
 N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
 N'IdleCPUDuration',
 @idle_cpu_duration OUTPUT,
 N'no_output'
 SELECT @schedule_description = FORMATMESSAGE(14578, ISNULL(@idle_cpu_percent, 10), ISNULL(@idle_cpu_duration, 600))
 RETURN @schedule_description
 END
-- Subday stuff
 SELECT @schedule_description = @schedule_description +
 CASE @freq_subday_type
 WHEN 0x1 THEN N'at ' + CONVERT(NVARCHAR, cast(
 CASE WHEN LEN(cast((@active_start_time / 10000)as varchar(10)))=1
     THEN  '0'+cast((@active_start_time / 10000) as varchar(10))
     ELSE cast((@active_start_time / 10000) as varchar(10))
     END    
as varchar(10)) + ':' + right('00' + cast((@active_start_time % 10000) / 100 as varchar(10)),2))
 WHEN 0x2 THEN N'every ' + CONVERT(NVARCHAR, @freq_subday_interval) + N' second(s)'
 WHEN 0x4 THEN N'every ' + CONVERT(NVARCHAR, @freq_subday_interval) + N' minute(s)'
 WHEN 0x8 THEN N'every ' + CONVERT(NVARCHAR, @freq_subday_interval) + N' hour(s)'
 END
 IF (@freq_subday_type IN (0x2, 0x4, 0x8))
 SELECT @schedule_description = @schedule_description + N' between ' +
CONVERT(NVARCHAR, cast(
CASE WHEN LEN(cast((@active_start_time / 10000)as varchar(10)))=1
     THEN  '0'+cast((@active_start_time / 10000) as varchar(10))
     ELSE cast((@active_start_time / 10000) as varchar(10))
     END    
as varchar(10)) + ':' + right('00' + cast((@active_start_time % 10000) / 100 as varchar(10)),2) ) 
+ N' and ' +
CONVERT(NVARCHAR, cast(
 CASE WHEN LEN(cast((@active_end_time / 10000)as varchar(10)))=1
     THEN  '0'+cast((@active_end_time / 10000) as varchar(10))
     ELSE cast((@active_end_time / 10000) as varchar(10))
     END    
as varchar(10)) + ':' + right('00' + cast((@active_end_time % 10000) / 100 as varchar(10)),2) )


RETURN @schedule_description
END
GO


CREATE TABLE [dbo].[Servers](
	[ServerId] [int] IDENTITY(1,1) NOT NULL,
	[EnvironmentId] [int] NULL,
	[PurposeId] [int] NULL,
	[ServerName] [varchar](100) NULL,
	[ServerDescription] [varchar](255) NULL,
	[WindowsRelease] [varchar](20) NULL,
	[CreatedDate] [datetime] NULL,
	[Version] [varchar](255) NULL,
	[Edition] [varchar](255) NULL,
	[ProductLevel] [varchar](50) NULL,
	[Collation] [varchar](50) NULL,
	[LogicalCPUCount] [int] NULL,
	[HyperthreadRatio] [int] NULL,
	[PhysicalCPUCount] [int] NULL,
	[PhysicalMemoryMB] [int] NULL,
	[VMType] [varchar](50) NULL,
	[Hardware] [varchar](100) NULL,
	[ProcessorNameString] [varchar](100) NULL,
	[BlockedProcessEvents] [varchar](255) NULL,
	[DeadlockEvents] [varchar](255) NULL,
	[ErrorEvents] [varchar](255) NULL,
	[LongQueryEvents] [varchar](255) NULL,
	[PerfMonLogs] [varchar](255) NULL,
	[IsActive] [bit] NULL,
	[IP] [varchar](30) NULL,
	[Error] [varchar](255) NULL,
	[BackupFolder] [varchar](500) NULL,
	[DailyChecks] [bit] NULL,
	[Domain] [varchar](100) NULL,
	[BackupChecks] [smallint] NULL,
	[Build] [varchar](50) NULL,
	[ErrorDate] [datetime] NULL,
	[resource_governor_enabled_functions] [tinyint] NULL,
	[RemoteUser] [varchar](100) NULL
 CONSTRAINT [PK_Servers] PRIMARY KEY CLUSTERED 
(
	[ServerId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Jobs](
	[JobId] [int] IDENTITY(1,1) NOT NULL,
	[ServerId] [int] NULL,
	[ServerName] [varchar](100) NULL,
	[Jobname] [varchar](255) NULL,
	[Description] [varchar](512) NULL,
	[IsEnabled] [bit] NULL,
	[ScheduleDscr] [nvarchar](255) NULL,
	[Operator] [varchar](100) NULL,
	[OperatorEnabled] [bit] NULL,
	[Operator_email_address] [nvarchar](100) NULL,
	[Owner] [varchar](100) NULL,
	[JobStartStepName] [varchar](255) NULL,
	[IsScheduled] [bit] NULL,
	[JobScheduleName] [varchar](255) NULL,
	[Frequency] [varchar](36) NULL,
	[Units] [varchar](21) NULL,
	[Active_start_date] [datetime] NULL,
	[Active_end_date] [datetime] NULL,
	[Run_Time] [varchar](8) NULL,
	[Created_Date] [varchar](24) NULL,
	[jobidentifier] [uniqueidentifier] NULL,
 CONSTRAINT [PK_Jobs] PRIMARY KEY CLUSTERED 
(
	[JobId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Databases](
	[DatabaseId] [int] IDENTITY(1,1) NOT NULL,
	[ServerId] [int] NULL,
	[DatabaseName] [varchar](100) NULL,
	[RecoveryModel] [varchar](100) NULL,
	[LogSizeKB] [bigint] NULL,
	[LogUsedKB] [bigint] NULL,
	[LogUsedPercentage] [varchar](50) NULL,
	[DBCompatibilityLevel] [varchar](50) NULL,
	[PageVerifyOption] [varchar](50) NULL,
	[is_auto_create_stats_on] [bit] NULL,
	[is_auto_update_stats_on] [bit] NULL,
	[is_auto_update_stats_async_on] [bit] NULL,
	[is_parameterization_forced] [bit] NULL,
	[snapshot_isolation_state_desc] [varchar](50) NULL,
	[is_read_committed_snapshot_on] [bit] NULL,
	[is_auto_close_on] [bit] NULL,
	[is_auto_shrink_on] [bit] NULL,
	[target_recovery_time_in_seconds] [int] NULL,
	[DataMB] [bigint] NULL,
	[LogMB] [bigint] NULL,
	[State_Desc] [varchar](100) NULL,
	[Create_Date] [datetime] NULL,
	[is_published] [bit] NULL,
	[is_subscribed] [bit] NULL,
	[Collation] [varchar](100) NULL,
	[CachedSizeMbs] [int] NULL,
	[CPUTime] [bigint] NULL,
	IOMbs bigint null,
	[Is_Read_Only] [bit] NULL,
	[delayed_durability_desc] [varchar](20) NULL,
	[containment_desc] [varchar](20) NULL,
	[is_cdc_enabled] [bit] NULL,
	[is_broker_enabled] [bit] NULL,
	[is_memory_optimized_elevate_to_snapshot_on] [bit] NULL,
	[AvailabilityGroup] [varchar](100) NULL,
	[PrimaryReplicaServerName] [varchar](100) NULL,
	[LocalReplicaRole] [tinyint] NULL,
	[SynchronizationState] [tinyint] NULL,
	[IsSuspended] [bit] NULL,
	[IsJoined] [bit] NULL,
	[SourceDatabaseName] [varchar](200) NULL,
	[owner] [varchar](100) NULL,
	[mirroring_state] [varchar](255) NULL,
	[mirroring_role] [varchar](255) NULL,
	[mirroring_safety_level] [varchar](255) NULL,
	[mirroring_partner] [varchar](255) NULL,
	[mirroring_partner_instance] [varchar](255) NULL,
	[mirroring_witness] [varchar](255) NULL,
	[mirroring_witness_state] [varchar](255) NULL,
	[mirroring_connection_timeout] [int] NULL,
	[mirroring_redo_queue] [int] NULL,
	[is_encrypted] [bit] NULL,
	[edition] [varchar](100) NULL,
	[service_objective] [varchar](100) NULL,
	[elastic_pool_name] [varchar](100) NULL,
 CONSTRAINT [PK_Databases] PRIMARY KEY CLUSTERED 
(
	[DatabaseId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[DatabaseObjects](
	[DatabaseObjectId] [int] IDENTITY(1,1) NOT NULL,
	[ServerId] [int] NULL,
	[DatabaseId] [int] NULL,
	[ObjectName] [varchar](200) NULL,
	[SchemaName] [varchar](100) NULL,
	[Xtype] [varchar](2) NULL,
	[RowCount] [bigint] NULL,
	[ColCount] [int] NULL,
	[MinCr_Ct] [datetime] NULL,
	[RowLength] [int] NULL,
	[ReplColumns] [int] NULL,
	[HasCr_Dt] [bit] NULL,
	[SQL_DATA_ACCESS] [varchar](20) NULL,
	[ROUTINE_DEFINITION] [varchar](max) NULL,
	[is_mspublished] [bit] NULL,
	[is_rplpublished] [bit] NULL,
	[is_rplsubscribed] [bit] NULL,
	[is_disabled] [bit] NULL,
	[parent_object_id] [int] NULL,
	[start_value] [bigint] NULL,
	[current_value] [bigint] NULL,
	[ParentSchema] [varchar](100) NULL,
	[ParentTable] [varchar](100) NULL,
	[ParentColumn] [varchar](100) NULL,
	[crdate] [datetime] NULL,
 CONSTRAINT [PK_DatabaseObjects] PRIMARY KEY CLUSTERED 
(
	[DatabaseObjectId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

CREATE TABLE [dbo].[IndexUsage](
	[ServerId] [int] NULL,
	[DatabaseId] [int] NULL,
	[data_space] [varchar](200) NULL,
	[allocation_desc] [varchar](200) NULL,
	[table_schema] [varchar](200) NULL,
	[object_type] [varchar](200) NULL,
	[table_name] [varchar](200) NULL,
	[index_type] [varchar](200) NULL,
	[index_name] [varchar](200) NULL,
	[is_unique] [bit] NULL,
	[is_disabled] [bit] NULL,
	[database_file] [varchar](200) NULL,
	[size_mbs] [int] NULL,
	[used_size] [int] NULL,
	[data_size] [int] NULL,
	[writes] [bigint] NULL,
	[reads] [bigint] NULL,
	[index_id] [int] NULL,
	[fill_factor] [float] NULL,
	[cols] [varchar](1000) NULL,
	[included] [varchar](8000) NULL,
	[filter_definition] [varchar](1000) NULL,
	[drop_cmd] [varchar](8000) NULL,
	[disable_cmd] [varchar](8000) NULL,
	[create_cmd] [varchar](8000) NULL,
	[DatabaseObjectId] [int] NULL,
	[rowid] [int] IDENTITY(1,1) NOT NULL,
	[data_compression_desc] [varchar](100) NULL,
 CONSTRAINT [pk_IndexUsage] PRIMARY KEY CLUSTERED 
(
	[rowid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]
GO




GO
CREATE TABLE [dbo].[DatabaseFiles](
	[DatabaseFileId] [int] IDENTITY(1,1) NOT NULL,
	[ServerId] [int] NULL,
	[DatabaseId] [int] NULL,
	[FileName] [varchar](200) NULL,
	[PhysicalName] [varchar](500) NULL,
	[TotalMbs] [int] NULL,
	[AvailableMbs] [int] NULL,
	[fileid] [int] NULL,
	[filegroupname] [varchar](100) NULL,
 CONSTRAINT [PK_DatabaseFiles] PRIMARY KEY CLUSTERED 
(
	[DatabaseFileId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]
GO


CREATE TABLE [dbo].[DatabaseObjectColumns](
	[DatabaseObjectColumnId] [int] IDENTITY(1,1) NOT NULL,
	[DatabaseObjectId] [int] NULL,
	[ServerId] [int] NULL,
	[DatabaseId] [int] NULL,
	[TABLE_CATALOG] [varchar](200) NULL,
	[TABLE_SCHEMA] [varchar](200) NULL,
	[TABLE_NAME] [varchar](200) NULL,
	[COLUMN_NAME] [varchar](200) NULL,
	[ORDINAL_POSITION] [int] NULL,
	[COLUMN_DEFAULT] [varchar](800) NULL,
	[IS_NULLABLE] [varchar](100) NULL,
	[DATA_TYPE] [varchar](100) NULL,
	[CHARACTER_MAXIMUM_LENGTH] [int] NULL,
	[COLLATION_NAME] [varchar](100) NULL,
	[is_computed] [bit] NULL,
	[is_identity] [bit] NULL,
 CONSTRAINT [PK_DatabaseObjectColumns] PRIMARY KEY CLUSTERED 
(
	[DatabaseObjectColumnId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]



GO

CREATE TABLE [dbo].[AvailabilityGroups](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[ServerId] [int] NULL,
	[AvailabiityGroup] [varchar](100) NULL,
	[replica_server_name] [varchar](100) NULL,
	[IsPrimaryServer] [bit] NULL,
	[ReadableSecondary] [bit] NULL,
	[Synchronous] [bit] NULL,
	[failover_mode_desc] [varchar](100) NULL,
	[synchronization_health_desc] [varchar](100) NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]
GO

GO
CREATE TABLE [dbo].[ClusterNodes](
	[ClusterNodeId] [int] IDENTITY(1,1) NOT NULL,
	[ServerId] [int] NULL,
	[NodeName] [varchar](512) NULL,
	[status] [int] NULL,
	[status_description] [varchar](512) NULL,
	[is_current_owner] [bit] NULL,
 CONSTRAINT [PK_ClusterNodes] PRIMARY KEY CLUSTERED 
(
	[ClusterNodeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]
GO


CREATE TABLE [dbo].[TopSql](
	[TopSqlId] [int] IDENTITY(1,1) NOT NULL,
	[ServerId] [int] NULL,
	[DatabaseId] [int] NULL,
	[SPName] varchar(255) NOT NULL,
	[TotalWorkerTime] [bigint] NOT NULL,
	[AvgWorkerTime] [bigint] NULL,
	[execution_count] [bigint] NOT NULL,
	[CallsPerSecond] [bigint] NOT NULL,
	[total_elapsed_time] [bigint] NOT NULL,
	[avg_elapsed_time] [bigint] NULL,
	[cached_time] [datetime] NULL,
 CONSTRAINT [PK_TopSql] PRIMARY KEY CLUSTERED 
(
	[TopSqlId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]
GO

GO
CREATE TABLE [dbo].[TopWait](
	[TopWaitId] [int] IDENTITY(1,1) NOT NULL,
	[ServerId] [int] NULL,
	[wait_type] [nvarchar](60) NOT NULL,
	[wait_time_ms] [bigint] NOT NULL,
	[signal_wait_time_ms] [bigint] NOT NULL,
	[resource_wait_time_ms] [bigint] NULL,
	[percent_total_waits] [numeric](38, 15) NULL,
	[percent_total_signal_waits] [numeric](38, 15) NULL,
	[percent_total_resource_waits] [numeric](38, 15) NULL,
 CONSTRAINT [PK_TopWait] PRIMARY KEY CLUSTERED 
(
	[TopWaitId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]
GO



GO

CREATE TABLE [dbo].[Volumes](
	[VolumeId] [int] IDENTITY(1,1) NOT NULL,
	[ServerId] [int] NULL,
	[volume_mount_point] [varchar](100) NULL,
	[TotalGB] [int] NULL,
	[AvailableGB] [int] NULL,
	[PercentageFree] [numeric](9, 2) NULL,
 CONSTRAINT [PK_Volumes] PRIMARY KEY CLUSTERED 
(
	[VolumeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]
GO


CREATE TABLE [dbo].[Services](
	[ServiceId] [int] IDENTITY(1,1) NOT NULL,
	[ServerId] [int] NULL,
	[servicename] [varchar](512) NULL,
	[startup_type] [int] NULL,
	[startup_type_desc] [varchar](512) NULL,
	[status] [int] NULL,
	[status_desc] [varchar](512) NULL,
	[process_id] [int] NULL,
	[last_startup_time] [datetime] NULL,
	[service_account] [varchar](512) NULL,
	[filename] [varchar](512) NULL,
	[is_clustered] [varchar](5) NULL,
	[cluster_nodename] [varchar](512) NULL,
 CONSTRAINT [PK_Services] PRIMARY KEY CLUSTERED 
(
	[ServiceId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]
GO




GO
CREATE TABLE [dbo].[JobSteps](
	[JobStepId] [int] IDENTITY(1,1) NOT NULL,
	[JobId] [int] NOT NULL,
	[job_name] [varchar](255) NULL,
	[ScheduleDscr] [varchar](255) NULL,
	[enabled] [bit] NULL,
	[step_id] [smallint] NULL,
	[step_name] [varchar](255) NULL,
	[database_name] [varchar](255) NULL,
	[command] [varchar](max) NULL,
	[proc_name] [varchar](255) NULL,
	[serverid] [int] NULL,
 CONSTRAINT [PK_JobSteps] PRIMARY KEY CLUSTERED 
(
	[JobStepId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

CREATE TABLE [dbo].[Sequences](
	[ServerId] [int] NULL,
	[DatabaseId] [int] NULL,
	[SequenceName] [varchar](100) NULL,
	[Current_value] [bigint] NULL,
	[ParentTable] [varchar](100) NULL,
	[ParentColumn] [varchar](100) NULL,
	[maxExisting] [bigint] NULL,
	[NextInUse] [bigint] NULL,
	[IsMax] [bit] NULL,
	[Gap] [bigint] NULL
) ON [PRIMARY]
GO

CREATE PROC [dbo].[spCleanup] @debug bit=0
AS

delete from dbo.Jobs
delete from dbo.Databases
delete from dbo.DatabaseObjects
delete from dbo.IndexUsage
delete from dbo.DatabaseFiles
delete from dbo.DatabaseObjectColumns
delete from dbo.AvailabilityGroups
delete from dbo.ClusterNodes
delete from dbo.TopSql
delete from dbo.TopWait
delete from dbo.Volumes
delete from dbo.Services
delete from dbo.JobSteps
delete from dbo.Sequences
delete from dbo.SysConfigurations

GO

create   proc [dbo].[spExecCommand] 
as
begin
	declare @sql varchar(max)
		, @message varchar(max)
		, @CommandId int
		, @ServerName varchar(100)
		, @Command varchar(max)

	declare @t table (CommandId int, ServerName varchar(100), command varchar(max) )

	update Command set StartDate = getdate()
	output deleted.CommandId, deleted.ServerName, deleted.Command into @t 
	where CommandId = ( 
		select top 1 CommandId from Command
		where StartDate is null
		order by Priority desc, CommandId
		)

	select @CommandId = t.CommandId
		, @ServerName = t.ServerName
		, @Command = t.Command
	from @t t

	begin  try
		set @sql = 'exec ('''+replace(@Command,'''','''''')+''') at ['+@ServerName+']'
		exec (@sql)
		update c set EndDate = getdate()
		from Command c
		join @t t on c.CommandId = t.CommandId
	end try
	begin catch
		select @CommandId CommandId, @Command Command, ERROR_MESSAGE() Message

		update c set EndDate = getdate()
			, Message = ERROR_MESSAGE()
		from Command c
		join @t t on c.CommandId = t.CommandId
	end catch

end
GO

CREATE   proc [dbo].[spLoadAvailabilityGroups] @serverid int=0
as

declare @sql nvarchar(max), @SERVER VARCHAR(100)
DECLARE T_CURSOR CURSOR FAST_FORWARD FOR
	SELECT SERVERNAME, serverid FROM SERVERS s
	where (Version like '%2012%' or Version like '%2014%' or Version like '%2016%' or Version like '%2017%' or Version like '%2019%')
	and Edition not like '%Azure%'
OPEN T_CURSOR
FETCH NEXT FROM T_CURSOR INTO @SERVER, @serverid 
WHILE @@FETCH_STATUS=0
BEGIN
	set @sql='
	SELECT serverid = '+cast(@serverid as varchar)+',
		name as AGname,
		replica_server_name,
		CASE WHEN  (primary_replica  = replica_server_name) THEN  1	ELSE  0 END AS IsPrimaryServer,
		secondary_role_allow_connections AS ReadableSecondary,
		[availability_mode]  AS [Synchronous],
		failover_mode_desc,
		states.synchronization_health_desc--, *
	FROM master.sys.availability_groups Groups
	INNER JOIN master.sys.availability_replicas Replicas ON Groups.group_id = Replicas.group_id
	INNER JOIN sys.dm_hadr_availability_group_states gs ON gs.group_id = Groups.group_id
	INNER JOIN sys.dm_hadr_availability_replica_states states ON Replicas.replica_id = states.replica_id
	'

	begin try
		insert into AvailabilityGroups (ServerId,AvailabiityGroup,replica_server_name,IsPrimaryServer,ReadableSecondary,Synchronous,failover_mode_desc,synchronization_health_desc)
		exec dbo.spExec @sql
	end try
	begin catch
		print error_message()
		print @sql
	end catch
	FETCH NEXT FROM T_CURSOR INTO @SERVER, @serverid
END
CLOSE T_CURSOR
DEALLOCATE T_CURSOR
--select * from jobs



GO


CREATE proc [dbo].[spLoadClusterNodes] @serverid int = 0
as
begin
if @serverid = 0
	delete from [ClusterNodes]

declare @sql nvarchar(max), @SERVER VARCHAR(100), @version varchar(20)
DECLARE T_CURSOR CURSOR FAST_FORWARD FOR
	SELECT SERVERNAME, serverid, MajorVersion FROM vwSERVERS s

OPEN T_CURSOR
FETCH NEXT FROM T_CURSOR INTO @SERVER, @serverid , @version
WHILE @@FETCH_STATUS=0
BEGIN
	if @version in ('2008','2008R2')
		set @sql='SELECT  distinct serverid = '+cast(@serverid as varchar)+', NodeName, null status, null status_description, null is_current_owner
	 from master.sys.dm_os_cluster_nodes'
	else set @sql='SELECT  distinct serverid = '+cast(@serverid as varchar)+', NodeName, status, status_description, is_current_owner
	 from master.sys.dm_os_cluster_nodes'
	
	begin try
		insert into [ClusterNodes] (ServerId, NodeName, status, status_description, is_current_owner)
		exec dbo.spExec @sql
	end try
	begin catch
		print error_message()
		print @sql
	end catch
	FETCH NEXT FROM T_CURSOR INTO @SERVER, @serverid, @version
END
CLOSE T_CURSOR
DEALLOCATE T_CURSOR
--select * from jobs
end
GO



CREATE proc [dbo].[spLoadDataBaseFiles] @serverid varchar(10)='0'
as

declare @linkedserver varchar(255)

/***********************
	DataBaseFiles
************************/
if @serverid = '0' 
	truncate table DatabaseFiles

declare @sql nvarchar(max), @SERVER VARCHAR(100), @DatabaseName varchar(100), @DatabaseId varchar(10), @version varchar(255)

DECLARE T_CURSOR CURSOR FAST_FORWARD FOR
	SELECT SERVERNAME, serverid, version FROM SERVERS s

OPEN T_CURSOR
FETCH NEXT FROM T_CURSOR INTO @server, @serverid, @version
WHILE @@FETCH_STATUS=0
BEGIN
	print @server
	declare d_cursor cursor fast_forward for
		select  databaseid, databasename from vwdatabases 
		where state_desc = 'online' 
		and ServerName = coalesce(PrimaryReplicaServerName,ServerName)
		and isnull(edition,'') <> 'DataWarehouse'

	open d_cursor
	FETCH NEXT FROM d_CURSOR INTO @databaseid, @databasename
	while @@FETCH_STATUS=0
	begin
		print @databasename
		set @sql='
			SELECT ServerId = '+cast(@Serverid as varchar)+'
				  , DatatabaseId = '+cast(@databaseid as varchar)+'
				  , f.name AS [File Name]
				  , f.physical_name AS [Physical Name]
				  , CAST(( f.size / 128.0 ) AS DECIMAL(10, 2)) AS [Total Size in MB]
				  , CAST(f.size / 128.0 - CAST(FILEPROPERTY(f.name, ''SpaceUsed'') AS INT) / 128.0 AS DECIMAL(10, 2)) AS [Available Space In MB]
				  , [file_id]
				  , fg.name AS [Filegroup Name]
			FROM    ['+@DatabaseName+'].sys.database_files AS f WITH ( NOLOCK )
					LEFT OUTER JOIN ['+@DatabaseName+'].sys.data_spaces AS fg WITH ( NOLOCK ) ON f.data_space_id = fg.data_space_id
			'
		if @DatabaseName = 'master' or @version not like '%azure%'
			set @linkedserver = @server
		else 
			set @linkedserver = @server+'.'+@DatabaseName

		
		begin try
			insert into DatabaseFiles (Serverid,DatabaseId,FileName,PhysicalName,TotalMbs,AvailableMbs,fileid,filegroupname)
			exec (@sql)
			--exec spExec @sql=@SQL, @debug=@debug, @exec=@exec, @raiserror= @debug
		end try
		begin catch
			print @sql
			print error_message()
		end catch
		FETCH NEXT FROM d_CURSOR INTO @databaseid, @databasename
	end
	close d_cursor
	deallocate d_cursor

	FETCH NEXT FROM T_CURSOR INTO @SERVER, @serverid, @version

END
CLOSE T_CURSOR
DEALLOCATE T_CURSOR
GO


CREATE proc [dbo].[spLoadDataBaseObjectColums] @serverid varchar(10)='0'
as

if @serverid = '0' 
	truncate table [DatabaseObjectColumns]

if object_id('tempdb..#dbs') is not null
	drop table #dbs

select distinct DatabaseId into #dbs from DatabaseObjectColumns doc 

declare @sql nvarchar(max), @SERVER VARCHAR(100), @DatabaseName varchar(100), @DatabaseId varchar(10), @version varchar(255), @linkedserver varchar(255)

DECLARE T_CURSOR CURSOR FAST_FORWARD FOR
	SELECT  SERVERNAME, serverid, version from servers s

OPEN T_CURSOR
FETCH NEXT FROM T_CURSOR INTO @SERVER, @serverid, @version
WHILE @@FETCH_STATUS=0
BEGIN
	declare d_cursor cursor fast_forward for
		select databaseid, databasename 
		from vwdatabases d 
		where serverid=@serverid 
		and state_desc= 'online' and ServerName = coalesce(PrimaryReplicaServerName,ServerName)
		and databasename not in ('master','msdb','tempdb','model')
		and databaseid not in (select DatabaseId from #dbs)
	open d_cursor
	FETCH NEXT FROM d_CURSOR INTO @databaseid, @databasename
	while @@FETCH_STATUS=0
	begin
		if @SERVER = @@SERVERNAME
			set @SERVER = '.' 
		set @sql='
		select '''+@DatabaseName+''' TABLE_CATALOG
			, s.name TABLE_SCHEMA
			, t.name TABLE_NAME
			, c.name COLUMN_NAME
			, c.column_id ORDINAL_POSITION
			, df.definition COLUMN_DEFAULT
			, c.is_nullable IS_NULLABLE
			, case when ty.name in (''nvarchar'',''nchar'', ''varchar'', ''char'', ''varbinary'') and c.max_length = -1 then  ty.name + '' (max)''
					when ty.name in (''nvarchar'',''nchar'') then ty.name + '' (''+ cast(c.max_length / 2 as varchar) +'')''
					when ty.name in (''varchar'',''char'', ''varbinary'') then ty.name + '' (''+ cast(c.max_length as varchar) +'')''
					when ty.name in (''numeric'', ''decimal'') then ty.name + '' (''+ cast(c.precision as varchar)+ '',''+ cast(c.scale as varchar) +'')''
					when ty.name in (''timestamp'',''rowversion'') then ''varbinary(8)''
					else ty.name end Data_Type 
			, c.max_length CHARACTER_MAXIMUM_LENGTH
			, c.collation_name COLLATION_NAME
			, c.is_computed, c.is_identity
		FROM ['+@DatabaseName+'].sys.tables t with (nolock)
		INNER JOIN ['+@DatabaseName+'].sys.schemas s on s.schema_id = t.schema_id
		inner join ['+@DatabaseName+'].sys.columns c on c.object_id = t.object_id 
		inner join ['+@DatabaseName+'].sys.types ty on ty.system_type_id = c.system_type_id and ty.name not in (''sysname'')
		left outer join ['+@DatabaseName+'].sys.default_constraints df on df.object_id = c.default_object_id
		where t.type=''U''
	   '
	
		if @DatabaseName = 'master' or @version not like '%azure%'
			set @linkedserver = @server
		else 
			set @linkedserver = @server+'.'+@DatabaseName

		SET @SQL = ' with a as ('+@sql+')
			SELECT '+@serverid+' as serverid, '+@databaseid+' as databaseid, do.databaseObjectId, a.TABLE_CATALOG, a.TABLE_SCHEMA, a.TABLE_NAME, a.COLUMN_NAME, a.ORDINAL_POSITION, a.COLUMN_DEFAULT, a.IS_NULLABLE, a.DATA_TYPE, a.CHARACTER_MAXIMUM_LENGTH, a.COLLATION_NAME, is_computed, is_identity
			FROM a
			LEFT JOIN DatabaseObjects do ON do.ObjectName = a.TABLE_NAME collate SQL_Latin1_General_CP1_CI_AS AND do.ServerId = '+@serverid+' and do.DatabaseId = '+@databaseid+' and do.SchemaName = a.TABLE_SCHEMA collate SQL_Latin1_General_CP1_CI_AS
			;'
		begin try
			insert into [DatabaseObjectColumns] (ServerId,DatabaseId,DatabaseObjectId, TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME,ORDINAL_POSITION,COLUMN_DEFAULT,IS_NULLABLE,DATA_TYPE,CHARACTER_MAXIMUM_LENGTH,COLLATION_NAME, is_computed, is_identity)
			exec dbo.spExec @sql
		end try
		begin catch
				exec [dbo].[spPrintLongSql] @sql
				print error_message()
		end catch
		FETCH NEXT FROM d_CURSOR INTO @databaseid, @databasename
	end
	close d_cursor
	deallocate d_cursor
	FETCH NEXT FROM T_CURSOR INTO @SERVER, @serverid, @version
END
CLOSE T_CURSOR
DEALLOCATE T_CURSOR


GO



CREATE proc [dbo].[spLoadDataBaseObjects] @debug bit=0, @exec bit=1, @serverid varchar(10)='0'
as
begin

/***********************
	DataBaseObjects
************************/
/*
delete from [dbo].[DatabaseObjectPerms]
delete from IndexUsage
delete from [dbo].[DatabaseObjectColumns]
delete from [dbo].[DatabaseObjects]
*/

declare @sql nvarchar(max), @SERVER VARCHAR(100), @DatabaseName varchar(100), @DatabaseId varchar(10), @Version	varchar	(255), @linkedserver varchar(255)
	, @edition varchar(100)

DECLARE T_CURSOR CURSOR FAST_FORWARD FOR
	SELECT  SERVERNAME, serverid, Version from Servers s
	
OPEN T_CURSOR
FETCH NEXT FROM T_CURSOR INTO @SERVER, @serverid , @Version
WHILE @@FETCH_STATUS=0
BEGIN
	if @SERVER = @@SERVERNAME
		set @SERVER = '.' 
	declare d_cursor cursor fast_forward for
		select databaseid, databasename, edition 
		from vwdatabases 
		where state_desc = 'online'and ServerName = coalesce(PrimaryReplicaServerName,ServerName)
		and databasename not in ('reportservertempdb','model','tempdb')
		and  serverid=@serverid
		order by 2
	open d_cursor
	FETCH NEXT FROM d_CURSOR INTO @databaseid, @databasename, @edition 
	while @@FETCH_STATUS=0
	begin 
		if @edition = 'DataWarehouse'
		set @sql='
				select o.name, s.name sch, xtype, coalesce(/*ps.rows,*/ r.rows, 0)
					, RowLength, ColCount, ReplColumns, hasCr_Dt
					, case when o.xtype= ''v'' then ''READS'' else rt.SQL_DATA_ACCESS end as SQL_DATA_ACCESS
					, coalesce(rt.ROUTINE_DEFINITION, rv.VIEW_DEFINITION, ck.definition, fk.delete_referential_action_desc collate SQL_Latin1_General_CP1_CI_AS) ROUTINE_DEFINITION
					, isnull(st.is_published,0) is_mspublished			
					, c.is_rplpublished
					, c.is_rplsubscribed
					, coalesce (ck.is_disabled, fk.is_disabled) is_disabled
					, o.parent_obj
					, null start_value, null  current_value
					, parentSchema, parentTable, parentColumn
					, o.crdate
				from ['+@DatabaseName+'].sys.sysobjects o WITH ( NOLOCK )
				left join ['+@DatabaseName+'].sys.tables st on st.object_id = o.id
		
				join ['+@DatabaseName+'].sys.schemas s WITH ( NOLOCK ) on o.uid=s.schema_id
				outer apply 
				(SELECT  SUM(Rows) AS [rows]
					FROM ['+@DatabaseName+'].sys.partitions p WITH ( NOLOCK )
					WHERE p.index_id < 2 and p.object_id = o.id	
					and o.xtype=''u''
				) r
				--outer apply /*does not work for round robin tables :-( */
				--(select sum(nps.[row_count]) rows
				--	from  ['+@DatabaseName+'].sys.pdw_table_mappings tm 
				--	INNER JOIN ['+@DatabaseName+'].sys.pdw_nodes_tables nt  ON tm.[physical_name] = nt.[name] 
				--	INNER JOIN ['+@DatabaseName+'].sys.dm_pdw_nodes_db_partition_stats nps ON nt.[object_id] = nps.[object_id]    AND nt.[pdw_node_id] = nps.[pdw_node_id]    AND nt.[distribution_id] = nps.[distribution_id]
				--	where nps.index_id = 1
				--	and tm.[object_id] = o.id
				--) ps
				outer apply 
				(SELECT  SUM(max_length) AS RowLength
						, count(*) as [ColCount]
						, sum(case when Is_Replicated=1 then 1 else 0 end) ReplColumns
						, sum(case when c.name = ''DateCreated'' then 1 else 0 end) hasCr_Dt 
						, sum(case when c.name = ''rv'' then 1 else 0 end) is_rplpublished 
						, sum(case when c.name = ''sourcerv'' then 1 else 0 end) is_rplsubscribed
					FROM ['+@DatabaseName+'].sys.columns c WITH ( NOLOCK )
					WHERE c.object_id = o.id 
					and o.xtype in (''U'',''V'')
				) c
				outer apply (
					select SQL_DATA_ACCESS, ROUTINE_DEFINITION
					from ['+@DatabaseName+'].INFORMATION_SCHEMA.ROUTINES rt WITH ( NOLOCK )
					where rt.SPECIFIC_SCHEMA = s.name
					and rt.ROUTINE_NAME=o.name
					and o.xtype in (''P'', ''FN'', ''IF'', ''TF'')
				) rt
				outer apply (
					select VIEW_DEFINITION
					from ['+@DatabaseName+'].INFORMATION_SCHEMA.VIEWS rv WITH ( NOLOCK )
					where rv.TABLE_SCHEMA = s.name
					and rv.TABLE_NAME=o.name
					and o.xtype = ''V''
				) rv
				outer apply (
					select is_disabled, definition from ['+@DatabaseName+'].sys.check_constraints ck
					where ck.name = o.name
					and o.xtype=''C''
				) ck
				outer apply (
					select is_disabled, delete_referential_action_desc from ['+@DatabaseName+'].sys.foreign_keys fk
					where fk.name = o.name
					and o.xtype=''F''
				) fk
				outer apply (
					select top 1 st.name parentSchema, t.name parentTable, ct.name as parentColumn
						from ['+@DatabaseName+'].sys.tables t
						join ['+@DatabaseName+'].sys.schemas st on st.schema_id=t.schema_id
						outer apply (select top 1 name 
								from ['+@DatabaseName+'].sys.columns ct 
								where  ct.object_id = t.object_id 
								and ct.system_type_id in (52,56,127)--int variations
								and ct.name not like ''%OLD''
								) ct
						where t.name = replace(o.name,''_seq'','''')
						and o.xtype=''SO''
					) p
				where o.xtype in (''U'', ''V'', ''P'', ''FN'', ''IF'', ''TF'', ''C'', ''F'')
				and o.NAME not like ''syncobj%''
			   '
		ELSE if @version like 'Microsoft SQL Server 2008%' or @version like 'Microsoft SQL Azure%' --WITHOUT SEQUENCES
		set @sql='
				select o.name, s.name sch, xtype, [RowCount]
					, RowLength, ColCount, ReplColumns, hasCr_Dt
					, case when o.xtype= ''v'' then ''READS'' else rt.SQL_DATA_ACCESS end as SQL_DATA_ACCESS
					, coalesce(rt.ROUTINE_DEFINITION, rv.VIEW_DEFINITION, ck.definition, fk.delete_referential_action_desc collate SQL_Latin1_General_CP1_CI_AS) ROUTINE_DEFINITION
					, isnull(st.is_published,0) is_mspublished			
					, c.is_rplpublished
					, c.is_rplsubscribed
					, coalesce (ck.is_disabled, fk.is_disabled) is_disabled
					, o.parent_obj
					, null start_value, null  current_value
					, parentSchema, parentTable, parentColumn
					, o.crdate
				from ['+@DatabaseName+'].sys.sysobjects o WITH ( NOLOCK )
				left join ['+@DatabaseName+'].sys.tables st on st.object_id = o.id
		
				join ['+@DatabaseName+'].sys.schemas s WITH ( NOLOCK ) on o.uid=s.schema_id
				outer apply 
				(SELECT  SUM(Rows) AS [RowCount]
					FROM ['+@DatabaseName+'].sys.partitions p WITH ( NOLOCK )
					WHERE p.index_id < 2 and p.object_id = o.id	
					and o.xtype=''u''
				) r
				outer apply 
				(SELECT  SUM(max_length) AS RowLength
						, count(*) as [ColCount]
						, sum(case when Is_Replicated=1 then 1 else 0 end) ReplColumns
						, sum(case when c.name = ''DateCreated'' then 1 else 0 end) hasCr_Dt 
						, sum(case when c.name = ''rv'' then 1 else 0 end) is_rplpublished 
						, sum(case when c.name = ''sourcerv'' then 1 else 0 end) is_rplsubscribed
					FROM ['+@DatabaseName+'].sys.columns c WITH ( NOLOCK )
					WHERE c.object_id = o.id 
					and o.xtype in (''U'',''V'')
				) c
				outer apply (
					select SQL_DATA_ACCESS, ROUTINE_DEFINITION
					from ['+@DatabaseName+'].INFORMATION_SCHEMA.ROUTINES rt WITH ( NOLOCK )
					where rt.SPECIFIC_SCHEMA = s.name
					and rt.ROUTINE_NAME=o.name
					and o.xtype in (''P'', ''FN'', ''IF'', ''TF'')
				) rt
				outer apply (
					select VIEW_DEFINITION
					from ['+@DatabaseName+'].INFORMATION_SCHEMA.VIEWS rv WITH ( NOLOCK )
					where rv.TABLE_SCHEMA = s.name
					and rv.TABLE_NAME=o.name
					and o.xtype = ''V''
				) rv
				outer apply (
					select is_disabled, definition from ['+@DatabaseName+'].sys.check_constraints ck
					where ck.name = o.name
					and o.xtype=''C''
				) ck
				outer apply (
					select is_disabled, delete_referential_action_desc from ['+@DatabaseName+'].sys.foreign_keys fk
					where fk.name = o.name
					and o.xtype=''F''
				) fk
				outer apply (
					select top 1 st.name parentSchema, t.name parentTable, ct.name as parentColumn
						from ['+@DatabaseName+'].sys.tables t
						join ['+@DatabaseName+'].sys.schemas st on st.schema_id=t.schema_id
						outer apply (select top 1 name 
								from ['+@DatabaseName+'].sys.columns ct 
								where  ct.object_id = t.object_id 
								and ct.system_type_id in (52,56,127)--int variations
								and ct.name not like ''%OLD''
								) ct
						where t.name = replace(o.name,''_seq'','''')
						and o.xtype=''SO''
					) p
				where o.xtype in (''U'', ''V'', ''P'', ''FN'', ''IF'', ''TF'', ''C'', ''F'')
				and o.NAME not like ''syncobj%''
			   '
		ELSE 
		set @sql='
		select o.name, s.name sch, xtype, [RowCount]
			, RowLength, ColCount, ReplColumns, hasCr_Dt
			, case when o.xtype= ''v'' then ''READS'' else rt.SQL_DATA_ACCESS end as SQL_DATA_ACCESS
			, coalesce(rt.ROUTINE_DEFINITION, rv.VIEW_DEFINITION, ck.definition, fk.delete_referential_action_desc collate SQL_Latin1_General_CP1_CI_AS) ROUTINE_DEFINITION
			, isnull(st.is_published,0) is_mspublished			
			, c.is_rplpublished
			, c.is_rplsubscribed
			, coalesce (ck.is_disabled, fk.is_disabled) is_disabled
			, o.parent_obj
			, so.start_value, so.current_value
			, parentSchema, parentTable, parentColumn
			, o.crdate
		from ['+@DatabaseName+'].sys.sysobjects o WITH ( NOLOCK )
		left join ['+@DatabaseName+'].sys.tables st on st.object_id = o.id
		
		join ['+@DatabaseName+'].sys.schemas s WITH ( NOLOCK ) on o.uid=s.schema_id
		outer apply 
		(SELECT  SUM(Rows) AS [RowCount]
			FROM ['+@DatabaseName+'].sys.partitions p WITH ( NOLOCK )
			WHERE p.index_id < 2 and p.object_id = o.id	
			and o.xtype=''u''
		) r
		outer apply 
		(SELECT  SUM(max_length) AS RowLength
				, count(*) as [ColCount]
				, sum(case when Is_Replicated=1 then 1 else 0 end) ReplColumns
				, sum(case when c.name = ''DateCreated'' then 1 else 0 end) hasCr_Dt 
				, sum(case when c.name = ''rv'' then 1 else 0 end) is_rplpublished 
				, sum(case when c.name = ''sourcerv'' then 1 else 0 end) is_rplsubscribed
			FROM ['+@DatabaseName+'].sys.columns c WITH ( NOLOCK )
			WHERE c.object_id = o.id 
			and o.xtype in (''U'',''V'')
		) c
		outer apply (
			select SQL_DATA_ACCESS, ROUTINE_DEFINITION
			from ['+@DatabaseName+'].INFORMATION_SCHEMA.ROUTINES rt WITH ( NOLOCK )
			where rt.SPECIFIC_SCHEMA = s.name
			and rt.ROUTINE_NAME=o.name
			and o.xtype in (''P'', ''FN'', ''IF'', ''TF'')
		) rt
		outer apply (
			select VIEW_DEFINITION
			from ['+@DatabaseName+'].INFORMATION_SCHEMA.VIEWS rv WITH ( NOLOCK )
			where rv.TABLE_SCHEMA = s.name
			and rv.TABLE_NAME=o.name
			and o.xtype = ''V''
		) rv
		outer apply (
			select is_disabled, definition from ['+@DatabaseName+'].sys.check_constraints ck
			where ck.name = o.name
			and o.xtype=''C''
		) ck
		outer apply (
			select is_disabled, delete_referential_action_desc from ['+@DatabaseName+'].sys.foreign_keys fk
			where fk.name = o.name
			and o.xtype=''F''
		) fk
		outer apply (
			select cast(s.current_value as bigint) current_value
				, cast(start_value as bigint)  start_value
			from ['+@DatabaseName+'].sys.sequences s
			where s.object_id = o.id
			and o.xtype=''SO''
			) so
		outer apply (
			select top 1 st.name parentSchema, t.name parentTable, ct.name as parentColumn
				from ['+@DatabaseName+'].sys.tables t
				join ['+@DatabaseName+'].sys.schemas st on st.schema_id=t.schema_id
				outer apply (select top 1 name 
						from ['+@DatabaseName+'].sys.columns ct 
						where  ct.object_id = t.object_id 
						and ct.system_type_id in (52,56,127)--int variations
						and ct.name not like ''%OLD''
						) ct
				where t.name = replace(o.name,''_seq'','''')
				and o.xtype=''SO''
			) p
		where o.xtype in (''U'', ''V'', ''P'', ''FN'', ''IF'', ''TF'', ''C'', ''F'', ''SO'')
		and o.NAME not like ''syncobj%''
	   '
		if @DatabaseName = 'master' or @version not like '%azure%'
			set @linkedserver = @server
		else 
			set @linkedserver = @server+'.'+@DatabaseName

		SET @SQL = 'with a as ('+@sql+')
		SELECT '+@serverid+', '+@databaseid+', a.*
			FROM a;'
		begin try
			insert into DatabaseObjects (Serverid,DatabaseId,ObjectName,SchemaName,Xtype,[RowCount], [RowLength], [ColCount], [ReplColumns], hasCr_Dt, SQL_DATA_ACCESS, ROUTINE_DEFINITION, is_mspublished, is_rplpublished, is_rplsubscribed, is_disabled, parent_object_id, start_value, current_value, parentSchema, parentTable, parentColumn, crdate)
			exec (@sql)
			--exec spExec @sql=@SQL, @debug=@debug, @exec=@exec, @raiserror= @debug
		end try
		begin catch
			print @sql
			print error_message()
		end catch
		FETCH NEXT FROM d_CURSOR INTO @databaseid, @databasename, @edition 
	end
	close d_cursor
	deallocate d_cursor

	FETCH NEXT FROM T_CURSOR INTO @SERVER, @serverid, @Version
END
CLOSE T_CURSOR
DEALLOCATE T_CURSOR
end


GO

CREATE proc [dbo].[spLoadDatabases] @serverid int=0 
as
begin
/**************
	DATABASES
**************/
if @serverid = '0'
	delete from databases
else 
	delete from databases where serverid=@serverid

declare @sql nvarchar(max)
	, @SERVER VARCHAR(100)--, @serverid int
	, @Version	varchar	(255)
DECLARE T_CURSOR CURSOR FAST_FORWARD FOR
	SELECT SERVERNAME, serverid, isnull(Version,'Microsoft SQL Server 2000')
	FROM SERVERS s
	
OPEN T_CURSOR
FETCH NEXT FROM T_CURSOR INTO @SERVER, @serverid, @Version
WHILE @@FETCH_STATUS=0
BEGIN
	if @SERVER = @@SERVERNAME
		set @SERVER = '.' 
	if @version like 'Microsoft SQL Server 2000%' 
		set @sql='SELECT  serverid = '+cast(@serverid as varchar)+'
				  , db.[name] 
				  , null recovery_model_desc
				  , null [Log Size (KB)]
				  , null [Log Used (KB)]
				  , null [Log Used %]
				  , null [DB Compatibility Level]
				  , null [Page Verify Option]
				  , null is_auto_create_stats_on
				  , null is_auto_update_stats_on
				  , null is_auto_update_stats_async_on
				  , null is_parameterization_forced
				  , null snapshot_isolation_state_desc
				  , null is_read_committed_snapshot_on
				  , null is_auto_close_on
				  , null is_auto_shrink_on
				  , null --target_recovery_time_in_seconds
				  , null Data
				  , null [Log] 
				  , null State_Desc
				  , null Create_Date
				  , null is_published
				  , null is_subscribed
				  , null Collation_name
				  , null [CachedSizeMBs]
				  , null AS [CPU_Time_Ms]
				  , null as IO
				  , null Is_Read_Only
				  , null delayed_durability_desc, null containment_desc, null is_cdc_enabled, null is_broker_enabled, null is_memory_optimized_elevate_to_snapshot_on	
				  , null AvailabilityGroup, null PrimaryReplicaServerName, null LocalReplicaRole, null SynchronizationState, null IsSuspended, null IsJoined
				  , null SourceDatabaseName, null owner
				  , null mirroring_state_desc, null mirroring_role_desc, null mirroring_safety_level_desc, null mirroring_partner_name, null mirroring_partner_instance
				  , null mirroring_witness_name, null mirroring_witness_state_desc, null mirroring_connection_timeout, null mirroring_redo_queue 
				  , null is_encrypted 	
				  , null edition, null service_objective, null elastic_pool_name
				 --select *
			FROM    master..sysdatabases AS db
			   '	
	else if @version like 'Microsoft SQL Server 2005%' 
		set @sql='SELECT  serverid = '+cast(@serverid as varchar)+'
				  , db.[name] AS [DatabaseName]
				  , db.recovery_model_desc AS [Recovery Model]
				  , ls.cntr_value AS [Log Size (KB)]
				  , lu.cntr_value AS [Log Used (KB)]
				  , CAST(CAST(lu.cntr_value AS FLOAT) / CAST(ls.cntr_value AS FLOAT) AS DECIMAL(18, 2)) * 100 AS [Log Used %]
				  , db.[compatibility_level] AS [DB Compatibility Level]
				  , db.page_verify_option_desc AS [Page Verify Option]
				  , db.is_auto_create_stats_on
				  , db.is_auto_update_stats_on
				  , db.is_auto_update_stats_async_on
				  , db.is_parameterization_forced
				  , db.snapshot_isolation_state_desc
				  , db.is_read_committed_snapshot_on
				  , db.is_auto_close_on
				  , db.is_auto_shrink_on
				  , -1 --target_recovery_time_in_seconds
				  , (SELECT  sum(CONVERT(BIGINT, size / 128.0)) AS [Total Size in MB]
					FROM    sys.master_files f WITH ( NOLOCK )
					WHERE   f.[database_id] = db.database_id
					and type_desc = ''Rows''
					) Data
				 , (SELECT  sum(CONVERT(BIGINT, size / 128.0)) AS [Total Size in MB]
					FROM    sys.master_files f WITH ( NOLOCK )
					WHERE   f.[database_id] = db.database_id
					and type_desc = ''Log''
					) [Log] 
				  , db.State_Desc
				  , db.Create_Date
				  , db.is_published
				  , db.is_subscribed
				  , db.Collation_name
				  , (SELECT COUNT(*) * 8 / 1024 
					FROM    sys.dm_os_buffer_descriptors d WITH ( NOLOCK )
					WHERE  d.database_id = -1--db.database_id
					) [CachedSizeMBs]
				  , ( SELECT    SUM(total_worker_time) 
					FROM     sys.dm_exec_query_stats AS qs
					CROSS APPLY ( SELECT    CONVERT(INT, value) AS [DatabaseID]
								  FROM      sys.dm_exec_plan_attributes(qs.plan_handle)
								  WHERE     attribute = N''dbid''
								   ) AS F_DB
					   where F_DB.[DatabaseID] = -1--db.Database_ID
					 ) AS [CPU_Time_Ms]
					 , 0  as IO
					 , db.Is_Read_Only
					 , null delayed_durability_desc, null containment_desc, null is_cdc_enabled, db.is_broker_enabled, null is_memory_optimized_elevate_to_snapshot_on	
					 , null AvailabilityGroup, null PrimaryReplicaServerName, null LocalReplicaRole, null SynchronizationState, null IsSuspended, null IsJoined
					 , ss.name SourceDatabaseName, l.loginname owner
					 , m.mirroring_state_desc, m.mirroring_role_desc, m.mirroring_safety_level_desc, m.mirroring_partner_name, m.mirroring_partner_instance
					 , m.mirroring_witness_name, m.mirroring_witness_state_desc, m.mirroring_connection_timeout, m.mirroring_redo_queue 
					 , null is_encrypted
				  , null edition, null service_objective, null elastic_pool_name
					 --select *
			FROM    master.sys.databases AS db
					LEFT JOIN master.sys.databases ss on ss.database_id = db.source_database_id
					LEFT JOIN master.sys.dm_os_performance_counters AS lu ON db.name = lu.instance_name and lu.counter_name LIKE N''Log File(s) Used Size (KB)%''
					LEFT JOIN master.sys.dm_os_performance_counters AS ls ON db.name = ls.instance_name AND ls.counter_name LIKE N''Log File(s) Size (KB)%'' AND ls.cntr_value > 0
					left join master..syslogins l on db.owner_sid = l.sid
					left join sys.database_mirroring m ON m.database_id = db.database_id
			OPTION  ( RECOMPILE );
			   '	
		else if @version like 'Microsoft SQL Server 2008%' 
		set @sql='SELECT  serverid = '+cast(@serverid as varchar)+'
				  , db.[name] AS [DatabaseName]
				  , db.recovery_model_desc AS [Recovery Model]
				  , ls.cntr_value AS [Log Size (KB)]
				  , lu.cntr_value AS [Log Used (KB)]
				  , CAST(CAST(lu.cntr_value AS FLOAT) / CAST(ls.cntr_value AS FLOAT) AS DECIMAL(18, 2)) * 100 AS [Log Used %]
				  , db.[compatibility_level] AS [DB Compatibility Level]
				  , db.page_verify_option_desc AS [Page Verify Option]
				  , db.is_auto_create_stats_on
				  , db.is_auto_update_stats_on
				  , db.is_auto_update_stats_async_on
				  , db.is_parameterization_forced
				  , db.snapshot_isolation_state_desc
				  , db.is_read_committed_snapshot_on
				  , db.is_auto_close_on
				  , db.is_auto_shrink_on
				  , -1 --target_recovery_time_in_seconds
				  , (SELECT  sum(CONVERT(BIGINT, size / 128.0)) AS [Total Size in MB]
					FROM    sys.master_files f WITH ( NOLOCK )
					WHERE   f.[database_id] = db.database_id
					and type_desc = ''Rows''
					) Data
				 , (SELECT  sum(CONVERT(BIGINT, size / 128.0)) AS [Total Size in MB]
					FROM    sys.master_files f WITH ( NOLOCK )
					WHERE   f.[database_id] = db.database_id
					and type_desc = ''Log''
					) [Log] 
				  , db.State_Desc
				  , db.Create_Date
				  , db.is_published
				  , db.is_subscribed
				  , db.Collation_name
				  , (SELECT COUNT(*) * 8 / 1024 
					FROM    sys.dm_os_buffer_descriptors d WITH ( NOLOCK )
					WHERE  d.database_id = -1--db.database_id
					) [CachedSizeMBs]
				  , ( SELECT    SUM(total_worker_time) 
					FROM     sys.dm_exec_query_stats AS qs
					CROSS APPLY ( SELECT    CONVERT(INT, value) AS [DatabaseID]
								  FROM      sys.dm_exec_plan_attributes(qs.plan_handle)
								  WHERE     attribute = N''dbid''
								   ) AS F_DB
					   where F_DB.[DatabaseID] = -1--db.Database_ID
					 ) AS [CPU_Time_Ms]
					 , 0 as IO
					 , db.Is_Read_Only
					 , null delayed_durability_desc, null containment_desc, db.is_cdc_enabled, db.is_broker_enabled, null is_memory_optimized_elevate_to_snapshot_on	
					 , null AvailabilityGroup, null PrimaryReplicaServerName, null LocalReplicaRole, null SynchronizationState, null IsSuspended, null IsJoined
					 , ss.name SourceDatabaseName, l.loginname owner
					 , m.mirroring_state_desc, m.mirroring_role_desc, m.mirroring_safety_level_desc, m.mirroring_partner_name, m.mirroring_partner_instance
					 , m.mirroring_witness_name, m.mirroring_witness_state_desc, m.mirroring_connection_timeout, m.mirroring_redo_queue 
					 , db.is_encrypted
				  , null edition, null service_objective, null elastic_pool_name
					 --select *
			FROM    master.sys.databases AS db
					LEFT JOIN master.sys.databases ss on ss.database_id = db.source_database_id
					LEFT JOIN master.sys.dm_os_performance_counters AS lu ON db.name = lu.instance_name and lu.counter_name LIKE N''Log File(s) Used Size (KB)%''
					LEFT JOIN master.sys.dm_os_performance_counters AS ls ON db.name = ls.instance_name AND ls.counter_name LIKE N''Log File(s) Size (KB)%'' AND ls.cntr_value > 0
					left join master..syslogins l on db.owner_sid = l.sid
					left join sys.database_mirroring m ON m.database_id = db.database_id
			OPTION  ( RECOMPILE );
			   '	
	else if @version like 'Microsoft SQL Server 2012%' 
		set @sql='SELECT  serverid = '+cast(@serverid as varchar)+'
				, db.[name] AS [DatabaseName]
			  , db.recovery_model_desc AS [Recovery Model]
			  , ls.cntr_value AS [Log Size (KB)]
			  , lu.cntr_value AS [Log Used (KB)]
			  , CAST(CAST(lu.cntr_value AS FLOAT) / CAST(ls.cntr_value AS FLOAT) AS DECIMAL(18, 2)) * 100 AS [Log Used %]
			  , db.[compatibility_level] AS [DB Compatibility Level]
			  , db.page_verify_option_desc AS [Page Verify Option]
			  , db.is_auto_create_stats_on
			  , db.is_auto_update_stats_on
			  , db.is_auto_update_stats_async_on
			  , db.is_parameterization_forced
			  , db.snapshot_isolation_state_desc
			  , db.is_read_committed_snapshot_on
			  , db.is_auto_close_on
			  , db.is_auto_shrink_on
			  , -1 --target_recovery_time_in_seconds
			  , (SELECT  sum(CONVERT(BIGINT, size / 128.0)) AS [Total Size in MB]
					FROM    sys.master_files f WITH ( NOLOCK )
					WHERE   f.[database_id] = db.database_id
					and type_desc = ''Rows''
					) Data
			 , (SELECT  sum(CONVERT(BIGINT, size / 128.0)) AS [Total Size in MB]
					FROM    sys.master_files f WITH ( NOLOCK )
					WHERE   f.[database_id] = db.database_id
					and type_desc = ''Log''
					) [Log] 
			  , db.State_Desc
			  , db.Create_Date
			  , db.is_published
			  , db.is_subscribed
			  , db.Collation_name
			  , (SELECT COUNT(*) * 8 / 1024 
				FROM    sys.dm_os_buffer_descriptors d WITH ( NOLOCK )
				WHERE  d.database_id = db.database_id
				) [CachedSizeMBs]
			  , ( SELECT    SUM(total_worker_time) 
				FROM     sys.dm_exec_query_stats AS qs
				CROSS APPLY ( SELECT    CONVERT(INT, value) AS [DatabaseID]
							  FROM      sys.dm_exec_plan_attributes(qs.plan_handle)
							  WHERE     attribute = N''dbid''
							   ) AS F_DB
				   where F_DB.[DatabaseID] = db.Database_ID
				 ) AS [CPU_Time_Ms]
				 , (SELECT CAST(SUM(num_of_bytes_read + num_of_bytes_written)/1048576 AS DECIMAL(12, 2)) AS io_in_mb
					FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS d
					WHERE  d.database_id = db.database_id )	 as IO			
				 , db.Is_Read_Only
				 , null delayed_durability_desc, db.containment_desc, db.is_cdc_enabled, db.is_broker_enabled, null is_memory_optimized_elevate_to_snapshot_on	
				 , ag.[AvailabilityGroupName], ag.PrimaryReplicaServerName, ag.LocalReplicaRole, ag.SynchronizationState, ag.IsSuspended, ag.IsJoined
				 , ss.name SourceDatabaseName, l.loginname owner
				 , m.mirroring_state_desc, m.mirroring_role_desc, m.mirroring_safety_level_desc, m.mirroring_partner_name, m.mirroring_partner_instance
				 , m.mirroring_witness_name, m.mirroring_witness_state_desc, m.mirroring_connection_timeout, m.mirroring_redo_queue 
				 , db.is_encrypted
				  , null edition, null service_objective, null elastic_pool_name
				 --select *
		FROM    master.sys.databases AS db
				LEFT JOIN master.sys.databases ss on ss.database_id = db.source_database_id
				LEFT JOIN master.sys.dm_os_performance_counters AS lu ON db.name = lu.instance_name and lu.counter_name LIKE N''Log File(s) Used Size (KB)%''
				LEFT JOIN master.sys.dm_os_performance_counters AS ls ON db.name = ls.instance_name AND ls.counter_name LIKE N''Log File(s) Size (KB)%'' AND ls.cntr_value > 0
				left join (
					SELECT
						AG.name AS [AvailabilityGroupName],
						agstates.primary_replica AS [PrimaryReplicaServerName],
						ISNULL(arstates.role, 3) AS [LocalReplicaRole],
						dbcs.database_name AS [DatabaseName],
						ISNULL(dbrs.synchronization_state, 0) AS [SynchronizationState],
						ISNULL(dbrs.is_suspended, 0) AS [IsSuspended],
						ISNULL(dbcs.is_database_joined, 0) AS [IsJoined]
					FROM master.sys.availability_groups AS AG
					LEFT OUTER JOIN master.sys.dm_hadr_availability_group_states as agstates   ON AG.group_id = agstates.group_id
					INNER JOIN master.sys.availability_replicas AS AR   ON AG.group_id = AR.group_id
					INNER JOIN master.sys.dm_hadr_availability_replica_states AS arstates   ON AR.replica_id = arstates.replica_id AND arstates.is_local = 1
					INNER JOIN master.sys.dm_hadr_database_replica_cluster_states AS dbcs   ON arstates.replica_id = dbcs.replica_id
					LEFT OUTER JOIN master.sys.dm_hadr_database_replica_states AS dbrs   ON dbcs.replica_id = dbrs.replica_id AND dbcs.group_database_id = dbrs.group_database_id
				) ag on ag.DatabaseName = db.name
				left join master..syslogins l on db.owner_sid = l.sid
				left join sys.database_mirroring m ON m.database_id = db.database_id
		OPTION  ( RECOMPILE );'
	else if @Version like 'Microsoft SQL Azure%'
		set @sql = 'SELECT  serverid = '+cast(@serverid as varchar)+'
			  , db.[name] AS [DatabaseName]
			  , db.recovery_model_desc AS [Recovery Model]
			  , null AS [Log Size (KB)]
			  , null AS [Log Used (KB)]
			  , null AS [Log Used %]
			  , db.[compatibility_level] AS [DB Compatibility Level]
			  , db.page_verify_option_desc AS [Page Verify Option]
			  , db.is_auto_create_stats_on
			  , db.is_auto_update_stats_on
			  , db.is_auto_update_stats_async_on
			  , db.is_parameterization_forced
			  , db.snapshot_isolation_state_desc
			  , db.is_read_committed_snapshot_on
			  , db.is_auto_close_on
			  , db.is_auto_shrink_on
			  , -0 --target_recovery_time_in_seconds
			  , 0 Data
			  , 0 [Log] 
			  , db.State_Desc
			  , db.Create_Date
			  , db.is_published
			  , db.is_subscribed
			  , db.Collation_name
			  , 0 [CachedSizeMBs]
			  , 0 AS [CPU_Time_Ms]
			  , 0 as IO
				 , db.Is_Read_Only
				 , null delayed_durability_desc, db.containment_desc, db.is_cdc_enabled, db.is_broker_enabled, null is_memory_optimized_elevate_to_snapshot_on	
				 , null [AvailabilityGroupName], null PrimaryReplicaServerName, null LocalReplicaRole, null SynchronizationState, null IsSuspended, null IsJoined
				 , null SourceDatabaseName, null  owner
				 , null mirroring_state_desc, null mirroring_role_desc, null mirroring_safety_level_desc, null mirroring_partner_name, null mirroring_partner_instance
				 , null mirroring_witness_name, null mirroring_witness_state_desc, null mirroring_connection_timeout, null mirroring_redo_queue 
				 , db.is_encrypted
				 , dso.edition,	dso.service_objective,	dso.elastic_pool_name
				 --select *
		FROM    master.sys.databases AS db
		left join [sys].[database_service_objectives] dso on db.database_id = dso.database_id
		OPTION  ( RECOMPILE );
		'
	else --latest versions
		set @sql='SELECT  serverid = '+cast(@serverid as varchar)+'
				, db.[name] AS [DatabaseName]
			  , db.recovery_model_desc AS [Recovery Model]
			  , ls.cntr_value AS [Log Size (KB)]
			  , lu.cntr_value AS [Log Used (KB)]
			  , CAST(CAST(lu.cntr_value AS FLOAT) / CAST(ls.cntr_value AS FLOAT) AS DECIMAL(18, 2)) * 100 AS [Log Used %]
			  , db.[compatibility_level] AS [DB Compatibility Level]
			  , db.page_verify_option_desc AS [Page Verify Option]
			  , db.is_auto_create_stats_on
			  , db.is_auto_update_stats_on
			  , db.is_auto_update_stats_async_on
			  , db.is_parameterization_forced
			  , db.snapshot_isolation_state_desc
			  , db.is_read_committed_snapshot_on
			  , db.is_auto_close_on
			  , db.is_auto_shrink_on
			  , -1 --target_recovery_time_in_seconds
			  , (SELECT  sum(CONVERT(BIGINT, size / 128.0)) AS [Total Size in MB]
					FROM    sys.master_files f WITH ( NOLOCK )
					WHERE   f.[database_id] = db.database_id
					and type_desc = ''Rows''
					) Data
			 , (SELECT  sum(CONVERT(BIGINT, size / 128.0)) AS [Total Size in MB]
					FROM    sys.master_files f WITH ( NOLOCK )
					WHERE   f.[database_id] = db.database_id
					and type_desc = ''Log''
					) [Log] 
			  , db.State_Desc
			  , db.Create_Date
			  , db.is_published
			  , db.is_subscribed
			  , db.Collation_name
			  , (SELECT COUNT(*) * 8 / 1024 
				FROM    sys.dm_os_buffer_descriptors d WITH ( NOLOCK )
				WHERE  d.database_id = db.database_id
				)  [CachedSizeMBs]
			  ,  (SELECT    SUM(total_worker_time) 
				FROM     sys.dm_exec_query_stats AS qs
				CROSS APPLY ( SELECT    CONVERT(INT, value) AS [DatabaseID]
							  FROM      sys.dm_exec_plan_attributes(qs.plan_handle)
							  WHERE     attribute = N''dbid''
							   ) AS F_DB
				   where F_DB.[DatabaseID] = db.Database_ID
				 )  AS [CPU_Time_Ms]
				 , (SELECT CAST(SUM(num_of_bytes_read + num_of_bytes_written)/1048576 AS DECIMAL(12, 2)) AS io_in_mb
					FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS [d]
					WHERE  d.database_id = db.database_id )	 as IO	
				 , db.Is_Read_Only
				 , db.delayed_durability_desc, db.containment_desc, db.is_cdc_enabled, db.is_broker_enabled, db.is_memory_optimized_elevate_to_snapshot_on	
				 , ag.[AvailabilityGroupName], ag.PrimaryReplicaServerName, ag.LocalReplicaRole, ag.SynchronizationState, ag.IsSuspended, ag.IsJoined
				 , ss.name SourceDatabaseName, l.loginname owner
				 , m.mirroring_state_desc, m.mirroring_role_desc, m.mirroring_safety_level_desc, m.mirroring_partner_name, m.mirroring_partner_instance
				 , m.mirroring_witness_name, m.mirroring_witness_state_desc, m.mirroring_connection_timeout, m.mirroring_redo_queue 
				 , db.is_encrypted
				  , null edition, null service_objective, null elastic_pool_name
				 --select *
		FROM    master.sys.databases AS db
				LEFT JOIN master.sys.databases ss on ss.database_id = db.source_database_id
				LEFT JOIN master.sys.dm_os_performance_counters AS lu ON db.name = lu.instance_name and lu.counter_name LIKE N''Log File(s) Used Size (KB)%''
				LEFT JOIN master.sys.dm_os_performance_counters AS ls ON db.name = ls.instance_name AND ls.counter_name LIKE N''Log File(s) Size (KB)%'' AND ls.cntr_value > 0
				left join (
					SELECT
						AG.name AS [AvailabilityGroupName],
						agstates.primary_replica AS [PrimaryReplicaServerName],
						ISNULL(arstates.role, 3) AS [LocalReplicaRole],
						dbcs.database_name AS [DatabaseName],
						ISNULL(dbrs.synchronization_state, 0) AS [SynchronizationState],
						ISNULL(dbrs.is_suspended, 0) AS [IsSuspended],
						ISNULL(dbcs.is_database_joined, 0) AS [IsJoined]
					FROM master.sys.availability_groups AS AG
					LEFT OUTER JOIN master.sys.dm_hadr_availability_group_states as agstates   ON AG.group_id = agstates.group_id
					INNER JOIN master.sys.availability_replicas AS AR   ON AG.group_id = AR.group_id
					INNER JOIN master.sys.dm_hadr_availability_replica_states AS arstates   ON AR.replica_id = arstates.replica_id AND arstates.is_local = 1
					INNER JOIN master.sys.dm_hadr_database_replica_cluster_states AS dbcs   ON arstates.replica_id = dbcs.replica_id
					LEFT OUTER JOIN master.sys.dm_hadr_database_replica_states AS dbrs   ON dbcs.replica_id = dbrs.replica_id AND dbcs.group_database_id = dbrs.group_database_id
				) ag on ag.DatabaseName = db.name
				left join master..syslogins l on db.owner_sid = l.sid
				left join sys.database_mirroring m ON m.database_id = db.database_id
		OPTION  ( RECOMPILE, maxdop 4 );
		   '
	/*
	SET @SQL = 'SELECT a.*	FROM OPENQUERY(['+@SERVER+'], 
		'''+replace(@sql, '''', '''''')+'''
		) AS a
		--where not exists (select * from databases d where d.serverid = '+cast(@serverid as varchar)+' and d.databasename=a.DatabaseName)
		;' */
	begin try
		insert into Databases (ServerId  ,
				DatabaseName 
				, RecoveryModel
				  , LogSizeKB 
				  , LogUsedKB 
				  , LogUsedPercentage 
				  , [DBCompatibilityLevel]
				  , [PageVerifyOption] 
				  , is_auto_create_stats_on 
				  , is_auto_update_stats_on 
				  , is_auto_update_stats_async_on 
				  , is_parameterization_forced 
				  , snapshot_isolation_state_desc 
				  , is_read_committed_snapshot_on 
				  , is_auto_close_on 
				  , is_auto_shrink_on 
				  , target_recovery_time_in_seconds 
				  , DataMB, LogMB
  				  , State_Desc
				  , Create_Date
				  , is_published
				  , is_subscribed
				  , Collation
				  , CachedSizeMbs
				  , IOMbs
				  , CPUTime
				  , Is_Read_Only
				  , delayed_durability_desc, containment_desc, is_cdc_enabled, is_broker_enabled, is_memory_optimized_elevate_to_snapshot_on	
				  , AvailabilityGroup, PrimaryReplicaServerName, LocalReplicaRole, SynchronizationState, IsSuspended, IsJoined
				  , SourceDatabaseName, owner
				  , mirroring_state, mirroring_role, mirroring_safety_level, mirroring_partner, mirroring_partner_instance
				  , mirroring_witness, mirroring_witness_state, mirroring_connection_timeout, mirroring_redo_queue
				  , is_encrypted
				  , edition, service_objective, elastic_pool_name
		 )
		exec(@sql)
	end try
	begin catch
		print error_message()
		print @sql
	end catch
	FETCH NEXT FROM T_CURSOR INTO @SERVER, @serverid, @Version
END
CLOSE T_CURSOR
DEALLOCATE T_CURSOR

--select * from Databases
end

GO



CREATE proc [dbo].[spLoadIndexUsage]  @serverid varchar(10)='0'
as

if @serverid = '0'
	truncate table [IndexUsage]

declare @sql nvarchar(max), @SERVER VARCHAR(100), @DatabaseName varchar(100), @DatabaseId varchar(10), @version varchar(255), @linkedserver varchar(255)

DECLARE T_CURSOR CURSOR FAST_FORWARD FOR
	SELECT SERVERNAME, serverid, version FROM SERVERS s

OPEN T_CURSOR
FETCH NEXT FROM T_CURSOR INTO @SERVER, @serverid , @version
WHILE @@FETCH_STATUS=0
BEGIN
	declare d_cursor cursor fast_forward for
		select databaseid, databasename from vwdatabases where serverid=@serverid and state_desc= 'online' 
		and databasename not in ('master','msdb','tempdb','model')
		 and ServerName = coalesce(PrimaryReplicaServerName,ServerName)
		 and isnull(edition,'') <> 'DataWarehouse'
	open d_cursor
	FETCH NEXT FROM d_CURSOR INTO @databaseid, @databasename
	while @@FETCH_STATUS=0
	begin
		set @sql='
with a as (
	SELECT ds.name AS data_space 
      , au.type_desc AS allocation_desc 
      , au.total_pages / 128 AS size_mbs 
      , au.used_pages / 128 AS used_size 
      , au.data_pages / 128 AS data_size 
      , sch.name AS table_schema 
      , obj.type_desc AS object_type       
      , obj.name AS table_name 
      , idx.type_desc AS index_type 
      , idx.name AS index_name 
	 , idx.is_unique
	 , idx.is_disabled
	 , idx.filter_definition
	 , d.[physical_name] AS [database_file]
	 , [writes]
	 , reads
	 , idx.index_id, fill_factor
	 , data_compression_desc
    , cols = stuff((select '', '' + name as [text()]
				from ['+@DatabaseName+'].sys.index_columns ic
				join ['+@DatabaseName+'].sys.columns c on ic.column_id = c.column_id AND c.object_id = ic.object_id
				 where ic.[object_id] = idx.object_id
					 and ic.[index_id] = idx.index_id
				and ic.is_included_column = 0
				order by ic.key_ordinal
			 for xml path('''')), 1, 2, '''')
    , included = stuff((select '', '' + name as [text()]
				from ['+@DatabaseName+'].sys.index_columns ic
				join ['+@DatabaseName+'].sys.columns c on ic.column_id = c.column_id AND c.object_id = ic.object_id
				 where ic.[object_id] = idx.object_id
					 and ic.[index_id] = idx.index_id
				and ic.is_included_column = 1
				order by index_column_id
			 for xml path('''')), 1, 2, '''')
FROM ['+@DatabaseName+'].sys.objects AS obj ( NOLOCK ) 
    INNER JOIN ['+@DatabaseName+'].sys.schemas AS sch ( NOLOCK ) ON obj.schema_id = sch.schema_id 
    INNER JOIN ['+@DatabaseName+'].sys.indexes AS idx  ( NOLOCK ) ON obj.object_id = idx.object_id
	LEFT JOIN  ['+@DatabaseName+'].sys.filegroups f ON f.[data_space_id] = idx.[data_space_id]
	LEFT JOIN  ['+@DatabaseName+'].sys.partitions AS PA  ( NOLOCK ) ON PA.object_id = idx.object_id and PA.index_id = idx.index_id 
	LEFT JOIN  ['+@DatabaseName+'].sys.allocation_units AS au ( NOLOCK ) ON (au.type IN (1, 3)  AND au.container_id = PA.hobt_id) 
            OR  (au.type = 2  AND au.container_id = PA.partition_id) 
	LEFT JOIN  ['+@DatabaseName+'].sys.data_spaces AS ds  ( NOLOCK ) ON ds.data_space_id = au.data_space_id 
    LEFT JOIN  ['+@DatabaseName+'].sys.database_files d ON f.[data_space_id] = d.[data_space_id]
     outer apply (
	   select isnull(user_updates,0) AS writes
		  , isnull(user_seeks,0) + isnull(user_scans,0) + isnull(user_lookups,0) AS reads
	   from ['+@DatabaseName+'].sys.dm_db_index_usage_stats AS s WITH ( NOLOCK )
	   where s.[object_id] = idx.[object_id]
	   and idx.index_id = s.index_id
	   and idx.is_disabled = 0
    ) usage
WHERE obj.type_desc in (''USER_TABLE'',''VIEW'')
), b as (
select data_space, allocation_desc, sum(size_mbs) size_mbs, sum(used_size) used_size, sum(data_size) data_size
	, table_schema
	, object_type, table_name, index_type, index_name, is_unique, is_disabled, filter_definition, min(database_file) database_file
	, sum(writes) writes, sum(reads) reads, index_id, fill_factor, cols, included, data_compression_desc
from a
group by data_space, allocation_desc, table_schema
	, object_type, table_name, index_type, index_name, is_unique, is_disabled, filter_definition
	, index_id, fill_factor, cols, included, data_compression_desc
)
SELECT '+@serverid+' as serverid, '+@databaseid+' as databaseid, data_space,allocation_desc,table_schema,object_type,table_name,index_type,index_name,is_unique,is_disabled,database_file,size_mbs,used_size,data_size,writes,reads,index_id,fill_factor, data_compression_desc,cols,included,filter_definition
from b
'
	
		if @DatabaseName = 'master' or @version not like '%azure%'
			set @linkedserver = @server
		else 
			set @linkedserver = @server+'.'+@DatabaseName

		begin try
			insert into [IndexUsage] (ServerId,DatabaseId, data_space,allocation_desc,table_schema,object_type,table_name,index_type,index_name,is_unique,is_disabled,database_file,size_mbs,used_size,data_size,writes,reads,index_id,fill_factor,data_compression_desc, cols,included,filter_definition)
			exec (@sql)
		end try
		begin catch
			exec spPrintLongSql @sql
			print error_message()
		end catch
		FETCH NEXT FROM d_CURSOR INTO @databaseid, @databasename
	end
	close d_cursor
	deallocate d_cursor
	FETCH NEXT FROM T_CURSOR INTO @SERVER, @serverid, @version
END
CLOSE T_CURSOR
DEALLOCATE T_CURSOR

upDATE IU SET DatabaseObjectId = (
	SELECT TOP 1 DatabaseObjectId 
	FROM DatabaseObjects DO
	WHERE DO.ServerId = IU.ServerId AND DO.DatabaseId = IU.DatabaseId
	AND IU.table_schema = DO.SchemaName AND IU.table_name =  do.ObjectName
	and do.Xtype='u'
	)
FROM [IndexUsage] IU 



GO



CREATE proc [dbo].[spLoadJobs] @serverid int = 0
as

/***********************************************
		JOBS
***********************************************/

if @serverid = '0'
begin
	delete from JobSteps
	delete from Jobs
end
else 
begin
	delete from JobErrors where serverid=@serverid
	delete from JobSteps where serverid=@serverid
	delete from Jobs where serverid=@serverid
end

declare @sql nvarchar(max), @SERVER VARCHAR(100)
DECLARE T_CURSOR CURSOR FAST_FORWARD FOR
	SELECT SERVERNAME, serverid FROM SERVERS s

OPEN T_CURSOR
FETCH NEXT FROM T_CURSOR INTO @SERVER, @serverid 
WHILE @@FETCH_STATUS=0
BEGIN
	if @SERVER = @@SERVERNAME
		set @SERVER = '.' 

	set @sql='
		SELECT  distinct serverid = '+cast(@serverid as varchar)+',
				j.[name]  ,
				j.[description] ,
				j.[enabled],
				dbo.udf_schedule_description(sch.freq_type,
											 sch.freq_interval,
											 sch.freq_subday_type,
											 sch.freq_subday_interval,
											 sch.freq_relative_interval,
											 sch.freq_recurrence_factor,
											 sch.active_start_date,
											 sch.active_end_date,
											 sch.active_start_time,
											 sch.active_end_time) AS ScheduleDscr ,

				o.name AS Operator ,
				o.enabled AS OperatorEnabled ,
				o.email_address AS Operator_email_address ,
				l.loginname AS owner,

				st.[step_name] AS [JobStartStepName] ,
				case when sch.[schedule_uid] is not null then 1 else 0 end AS [IsScheduled] ,
				sch.[name] AS [JobScheduleName] ,
				''Frequency'' = CASE WHEN sch.freq_type = 1
															 THEN ''Once''
															 WHEN sch.freq_type = 4
															 THEN ''Daily''
															 WHEN sch.freq_type = 8
															 THEN ''Weekly''
															 WHEN sch.freq_type = 16
															 THEN ''Monthly''
															 WHEN sch.freq_type = 32
															 THEN ''Monthly relative''
															 WHEN sch.freq_type = 32
															 THEN ''Execute when SQL Server Agent starts''
														END ,
				''Units'' = CASE WHEN sch.freq_subday_type = 1
															THEN ''At the specified time''
															WHEN sch.freq_subday_type = 2
															THEN ''Seconds''
															WHEN sch.freq_subday_type = 4
															THEN ''Minutes''
															WHEN sch.freq_subday_type = 8
															THEN ''Hours''
													   END ,
				CAST(CAST(sch.active_start_date AS VARCHAR(15)) AS DATETIME) AS active_start_date ,
				CAST(CAST(sch.active_end_date AS VARCHAR(15)) AS DATETIME) AS active_end_date ,
				STUFF(STUFF(RIGHT(''000000'' + CAST(jsch.next_run_time AS VARCHAR), 6),
							3, 0, '':''), 6, 0, '':'') AS Run_Time ,
				CONVERT(VARCHAR(24), sch.date_created) AS Created_Date,
				j.job_id, @@servername
		FROM    [msdb].[dbo].[sysjobs] AS j
				LEFT JOIN [msdb].[sys].[servers] AS s ON j.[originating_server_id] = s.[server_id]
				LEFT JOIN [msdb].[dbo].[syscategories] AS c ON j.[category_id] = c.[category_id]
				LEFT JOIN [msdb].[dbo].[sysjobsteps] AS st ON j.[job_id] = st.[job_id]
															  AND j.[start_step_id] = st.[step_id]
				LEFT JOIN [msdb].[sys].[database_principals] AS prin ON j.[owner_sid] = prin.[sid]
				outer apply(select top 1 * from  [msdb].[dbo].[sysjobschedules] AS jsch where j.[job_id] = jsch.[job_id] ) jsch
				LEFT JOIN [msdb].[dbo].[sysschedules] AS sch ON jsch.[schedule_id] = sch.[schedule_id]
		
				LEFT OUTER JOIN msdb.dbo.sysoperators AS o WITH ( NOLOCK ) ON j.notify_email_operator_id = o.id
				LEFT OUTER JOIN master.sys.syslogins AS l WITH ( NOLOCK ) ON j.owner_sid = l.sid
		ORDER BY 1
		   '
	/*
	SET @SQL = 'SELECT a.*	FROM OPENQUERY(['+@SERVER+'], 
		'''+replace(@sql, '''', '''''')+'''
		) AS a;'*/
	begin try
		insert into jobs (ServerId,Jobname,Description,IsEnabled,ScheduleDscr,Operator,OperatorEnabled,Operator_email_address,Owner,JobStartStepName,IsScheduled,JobScheduleName,Frequency,Units,Active_start_date,Active_end_date,Run_Time,Created_Date, [jobidentifier], servername)
		exec (@sql)
	end try
	begin catch
		print error_message()
		print @sql
	end catch
	FETCH NEXT FROM T_CURSOR INTO @SERVER, @serverid
END
CLOSE T_CURSOR
DEALLOCATE T_CURSOR
--select * from jobs

GO


CREATE proc [dbo].[spLoadJobSteps] @serverid varchar(10)='0'
as
if @serverid = '0'
	truncate table JobSteps
else 
	delete from JobSteps where serverid=@serverid

/**********************************************
	JOB StepS
***********************************************/
declare @sql nvarchar(max), @SERVER VARCHAR(100)
DECLARE T_CURSOR CURSOR FAST_FORWARD FOR
	SELECT SERVERNAME, serverid FROM SERVERS s

OPEN T_CURSOR
FETCH NEXT FROM T_CURSOR INTO @SERVER, @serverid 
WHILE @@FETCH_STATUS=0
BEGIN
	if @SERVER = @@SERVERNAME
		set @SERVER = '.' 

	set @sql='
		SELECT 	serverid = '+cast(@serverid as varchar)+', j.[name] job_name ,
			dbo.udf_schedule_description(sch.freq_type,
											 sch.freq_interval,
											 sch.freq_subday_type,
											 sch.freq_subday_interval,
											 sch.freq_relative_interval,
											 sch.freq_recurrence_factor,
											 sch.active_start_date,
											 sch.active_end_date,
											 sch.active_start_time,
											 sch.active_end_time) AS ScheduleDscr ,
			j.[enabled],
			st.step_id,
			st.[step_name] ,
			st.database_name,
			st.command,
			j.job_id
		FROM [msdb].[dbo].[sysjobs] AS j
		LEFT JOIN [msdb].[dbo].[sysjobsteps] AS st ON j.[job_id] = st.[job_id]  
		outer apply(select top 1 * from  [msdb].[dbo].[sysjobschedules] AS jsch where j.[job_id] = jsch.[job_id] ) jsch
		LEFT JOIN [msdb].[dbo].[sysschedules] AS sch ON jsch.[schedule_id] = sch.[schedule_id]
		'
	
		SET @SQL = 'with a  as ('+@sql+')
		SELECT serverid = '+cast(@serverid as varchar)+', j.jobid, a.job_name, a.ScheduleDscr,a.enabled,a.step_id,a.step_name,a.database_name,a.command 
		FROM  a
		join jobs j on j.serverid = '+@serverid+' and j.jobidentifier = a.job_id
			;'
	begin try
		--print @sql
			insert into jobSteps (serverid,JobId,job_name,ScheduleDscr,enabled,step_id,step_name,database_name,command )
			exec (@sql)
	end try
	begin catch
		print error_message()
		print @sql
	end catch
	FETCH NEXT FROM T_CURSOR INTO @SERVER, @serverid
END
CLOSE T_CURSOR
DEALLOCATE T_CURSOR
--select * from jobSteps

GO

CREATE proc [dbo].[spLoadSequences] @serverid int=0
as
set nocount on
truncate table Sequences

declare @Server varchar(100), @DatabaseName varchar(100), @SchemaName varchar(100), @ObjectName varchar(100),
		 @ParentSchema varchar(100), @ParentTable varchar(100), @ParentColumn varchar(100), @current_value bigint,
		  @databaseid int, @version varchar(255), @linkedserver varchar(255)

declare @sql nvarchar(max)

DECLARE T_CURSOR CURSOR FAST_FORWARD FOR
	select ServerName, DatabaseName, SchemaName, ObjectName,
		 ParentSchema, ParentTable, ParentColumn, current_value
		 , s.serverid, d.databaseid , s.version
	 from DatabaseObjects do
	 join databases d on d.databaseid=do.databaseid
	 join servers s on s.serverid=d.serverid
	where xtype in ('SO')
	
open T_CURSOR
fetch next from T_CURSOR into @Server, @DatabaseName, @SchemaName, @ObjectName, @ParentSchema, @ParentTable, @ParentColumn, @current_value , @serverid, @databaseid , @version
while @@FETCH_STATUS=0
begin

	set @sql='SELECT '+cast(@serverid as varchar)+' as serverid
		, '+cast(@DatabaseId as varchar)+' as DatabaseId
		, '''+@SchemaName+'.'+@ObjectName+''' assequenceName
		, current_value as current_value
		, '''+@parentSchema+'.'+@parentTable+''' as parentTable
		, '''+@parentColumn+''' as parentColumn
		, (select max(['+@parentColumn+']) from ['+ @DatabaseName+'].['+ @parentSchema+'].['+@parentTable+']) as maxExisting
		, (select min(['+@parentColumn+']) from ['+ @DatabaseName+'].['+ @parentSchema+'].['+@parentTable+'] where ['+@parentColumn+'] > s.current_value) as NextInUse
	from (
		select cast(current_value as bigint) current_value 
		from ['+ @DatabaseName+'].sys.sequences s 
		where s.name = '''+@ObjectName+'''
		) s
	'
	
	if @DatabaseName = 'master' or @version not like '%azure%'
			set @linkedserver = @server
		else 
			set @linkedserver = @server+'.'+@DatabaseName

	/*SET @SQL = 'SELECT a.*	FROM OPENQUERY(['+@linkedserver+'], 
		'''+replace(@sql, '''', '''''')+'''
		) AS a;'*/
	print @sql
	begin try
		insert into Sequences (ServerId,DatabaseId,SequenceName,Current_value,ParentTable,ParentColumn,maxExisting,NextInUse)
		exec (@sql)
	end try
	begin catch
		print error_message()
		print @sql
	end catch

	fetch next from T_CURSOR into @Server, @DatabaseName, @SchemaName, @ObjectName, @ParentSchema, @ParentTable, @ParentColumn, @current_value , @serverid, @databaseid , @version

end
close T_CURSOR
deallocate T_CURSOR

update Sequences set IsMax = case when current_value < maxExisting then 1 else 0 end 
	, Gap =  NextInUse - current_value 

GO

CREATE proc [dbo].[spLoadServers]  @debug BIT=0
AS
BEGIN 

/**************
	SERVERS
**************/
if OBJECT_ID('tempdb..#t') is not null
	drop table #t

CREATE table #t  (
	ServerName varchar(100),
	WindowsRelease varchar(20),
	CreatedDate datetime,
	Version varchar(255),
	Edition varchar(255),
	ProductLevel varchar(50),
	Collation varchar(50),
	LogicalCPUCount int,
	HyperthreadRatio int,
	PhysicalCPUCount int,
	PhysicalMemoryMB int,
	VMType varchar(50),
	Build varchar(50),
	resource_governor_enabled_functions tinyint
	)

declare @sql nvarchar(max), @SERVER VARCHAR(100), @error varchar(255), @version varchar(200)
DECLARE T_CURSOR CURSOR FAST_FORWARD FOR
	SELECT SERVERNAME, isnull(Version,'Microsoft SQL Server 2000')
	FROM vwSERVERS 
	ORDER BY ServerName

OPEN T_CURSOR
FETCH NEXT FROM T_CURSOR INTO @SERVER, @version
WHILE @@FETCH_STATUS=0
BEGIN
	if @SERVER = @@SERVERNAME
		set @SERVER = '.' 

	if @version like 'Microsoft SQL Server  2000%'or @version like '%azure%'
		set @sql='SELECT @@ServerName ServerName
					   , null--  (SELECT cast(windows_release as varchar) FROM    sys.dm_os_windows_info) windows_release
					   , null--(SELECT  createdate AS [Server Name] FROM  sys.syslogins WHERE   [sid] = 0x010100000000000512000000) createdate
					   , cast(@@VERSION as varchar(255)) AS [SQL Server and OS Version Info]
					   , cast(SERVERPROPERTY(''Edition'') as varchar) AS [Edition]
					   , cast(SERVERPROPERTY(''ProductLevel'') as varchar) AS [ProductLevel]
					   , cast(SERVERPROPERTY(''Collation'') as varchar) AS [Collation]
					   , null--(SELECT  cpu_count FROM    sys.dm_os_sys_info) cpu_count
					   , null--(SELECT  hyperthread_ratio FROM    sys.dm_os_sys_info) hyperthread_ratio
					   , null--(SELECT  cpu_count / hyperthread_ratio FROM    sys.dm_os_sys_info) Physical_cpu
					   , null--(SELECT  physical_memory_in_bytes / 1024 /1024 FROM    sys.dm_os_sys_info) [Memory]
					   , null -- (SELECT  virtual_machine_type_desc FROM    sys.dm_os_sys_info) VM
					   , cast(SERVERPROPERTY(''ProductVersion'') as varchar(50)) Build
					    , null resource_governor_enabled_functions
					   '
	else if @version like 'Microsoft SQL Server 2005%' 
		set @sql='SELECT @@ServerName ServerName
					   , null--  (SELECT cast(windows_release as varchar) FROM    sys.dm_os_windows_info) windows_release
					   , (SELECT  createdate AS [Server Name] FROM  sys.syslogins WHERE   [sid] = 0x010100000000000512000000) createdate
					   , cast(@@VERSION as varchar(255)) AS [SQL Server and OS Version Info]
					   , cast(SERVERPROPERTY(''Edition'') as varchar) AS [Edition]
					   , cast(SERVERPROPERTY(''ProductLevel'') as varchar) AS [ProductLevel]
					   , cast(SERVERPROPERTY(''Collation'') as varchar) AS [Collation]
					   , (SELECT  cpu_count FROM    sys.dm_os_sys_info) cpu_count
					   , (SELECT  hyperthread_ratio FROM    sys.dm_os_sys_info) hyperthread_ratio
					   , (SELECT  cpu_count / hyperthread_ratio FROM    sys.dm_os_sys_info) Physical_cpu
					   , (SELECT  physical_memory_in_bytes / 1024 /1024 FROM    sys.dm_os_sys_info) [Memory]
					   , null -- (SELECT  virtual_machine_type_desc FROM    sys.dm_os_sys_info) VM
					   , cast(SERVERPROPERTY(''ProductVersion'') as varchar(50)) Build
					   , null resource_governor_enabled_functions
					   '
	else if  @version like 'Microsoft SQL Server 2008%' 
		set @sql='SELECT @@ServerName ServerName
					   , null--  (SELECT cast(windows_release as varchar) FROM    sys.dm_os_windows_info) windows_release
					   , (SELECT  createdate AS [Server Name] FROM  sys.syslogins WHERE   [sid] = 0x010100000000000512000000) createdate
					   , cast(@@VERSION as varchar(255)) AS [SQL Server and OS Version Info]
					   , cast(SERVERPROPERTY(''Edition'') as varchar) AS [Edition]
					   , cast(SERVERPROPERTY(''ProductLevel'') as varchar) AS [ProductLevel]
					   , cast(SERVERPROPERTY(''Collation'') as varchar) AS [Collation]
					   , (SELECT  cpu_count FROM    sys.dm_os_sys_info) cpu_count
					   , (SELECT  hyperthread_ratio FROM    sys.dm_os_sys_info) hyperthread_ratio
					   , (SELECT  cpu_count / hyperthread_ratio FROM    sys.dm_os_sys_info) Physical_cpu
					   , (SELECT  physical_memory_in_bytes / 1024 /1024 FROM    sys.dm_os_sys_info) [Memory]
					   , null -- (SELECT  virtual_machine_type_desc FROM    sys.dm_os_sys_info) VM
					   , cast(SERVERPROPERTY(''ProductVersion'') as varchar(50)) Build
					   , (select count(*) from sys.resource_governor_configuration where is_enabled=1) resource_governor_enabled_functions
					   '
	else 
		set @sql='SELECT @@ServerName ServerName
		   , (SELECT cast(windows_release as varchar) FROM    sys.dm_os_windows_info) windows_release
		   , (SELECT  createdate AS [Server Name] FROM  sys.syslogins WHERE   [sid] = 0x010100000000000512000000) createdate
		   , cast(@@VERSION as varchar(255)) AS [SQL Server and OS Version Info]
		   , cast(SERVERPROPERTY(''Edition'') as varchar) AS [Edition]
		   , cast(SERVERPROPERTY(''ProductLevel'') as varchar) AS [ProductLevel]
		   , cast(SERVERPROPERTY(''Collation'') as varchar) AS [Collation]
		   , (SELECT  cpu_count FROM    sys.dm_os_sys_info) cpu_count
		   , (SELECT  hyperthread_ratio FROM    sys.dm_os_sys_info) hyperthread_ratio
		   , (SELECT  cpu_count / hyperthread_ratio FROM    sys.dm_os_sys_info) Physical_cpu
		   , (SELECT  physical_memory_kb / 1024  FROM    sys.dm_os_sys_info) [Memory]
		   , (SELECT  virtual_machine_type_desc FROM    sys.dm_os_sys_info) VM
		   , cast(SERVERPROPERTY(''ProductVersion'') as varchar(50)) Build
		    , (select count(*) from sys.resource_governor_configuration where is_enabled=1) resource_governor_enabled_functions
		   '
	
	BEGIN TRY
		insert into #t
		exec (@sql)--dbo.spExec @sql= @sql, @raiserror = 1, @debug = @debug

	END TRY
    BEGIN CATCH
		PRINT @sql
		PRINT ERROR_MESSAGE()
	END catch


	FETCH NEXT FROM T_CURSOR INTO @SERVER,  @version
END
CLOSE T_CURSOR
DEALLOCATE T_CURSOR
	
	UPDATE S SET 
		WindowsRelease = t.WindowsRelease,
		CreatedDate = t.CreatedDate,
		Version = t.Version,
		Edition = t.Edition,
		ProductLevel = t.ProductLevel ,
		Collation = t.Collation,
		LogicalCPUCount = t.LogicalCPUCount,
		HyperthreadRatio = t.HyperthreadRatio,
		PhysicalCPUCount = t.PhysicalCPUCount,
		PhysicalMemoryMB = t.PhysicalMemoryMB,
		VMType = t.VMType,
		Build = t. Build,
		resource_governor_enabled_functions = t.resource_governor_enabled_functions
	FROM SERVERS S 
	join #t t on t.servername = s.servername 

	--select *  FROM SERVERS
END

GO


CREATE proc [dbo].[spLoadServices] @serverid int=0
as

declare @sql nvarchar(max), @SERVER VARCHAR(100)
DECLARE T_CURSOR CURSOR FAST_FORWARD FOR
	SELECT SERVERNAME, serverid FROM SERVERS s

OPEN T_CURSOR
FETCH NEXT FROM T_CURSOR INTO @SERVER, @serverid 
WHILE @@FETCH_STATUS=0
BEGIN
	if @SERVER = @@SERVERNAME
		set @SERVER = '.' 
	set @sql='SELECT  distinct serverid = 1, servicename,startup_type,startup_type_desc,status,status_desc,process_id,last_startup_time,service_account,filename,is_clustered,cluster_nodename
	 from master.sys.dm_server_services'

	begin try
		insert into [Services] (ServerId,servicename,startup_type,startup_type_desc,status,status_desc,process_id,last_startup_time,service_account,filename,is_clustered,cluster_nodename)
		exec dbo.spExec @sql
	end try
	begin catch
		print error_message()
		print @sql
	end catch
	FETCH NEXT FROM T_CURSOR INTO @SERVER, @serverid
END
CLOSE T_CURSOR
DEALLOCATE T_CURSOR
--select * from jobs



GO

CREATE proc [dbo].[spLoadTopSql]  @serverid varchar(10)='0'
as
/***********************
	TopSql
************************/
if @serverid = '0'
	truncate table TopSql
else 
	delete from TopSql where serverid = @serverid

declare @sql nvarchar(max), @SERVER VARCHAR(100), @DatabaseName varchar(100), @DatabaseId varchar(10), @version varchar(255), @linkedserver varchar(255)

DECLARE T_CURSOR CURSOR FAST_FORWARD FOR
	SELECT SERVERNAME, serverid, version FROM SERVERS s
	
OPEN T_CURSOR
FETCH NEXT FROM T_CURSOR INTO @SERVER, @serverid , @version
WHILE @@FETCH_STATUS=0
BEGIN
	declare d_cursor cursor fast_forward for
		select databaseid, databasename from vwdatabases where state_desc = 'online' 
	open d_cursor
	FETCH NEXT FROM d_CURSOR INTO @databaseid, @databasename
	while @@FETCH_STATUS=0
	begin
		if @SERVER = @@SERVERNAME
			set @SERVER = '.' 
		set @sql='
		SELECT TOP ( 10 )
				s.name + ''.''+ p.name AS [SP Name]
			  , qs.total_worker_time AS [TotalWorkerTime]
			  , qs.total_worker_time / qs.execution_count AS [AvgWorkerTime]
			  , qs.execution_count
			  , case when DATEDIFF(Second, qs.cached_time, GETDATE()) > 0 then qs.execution_count / DATEDIFF(Second, qs.cached_time, GETDATE()) else 0 end AS [Calls/Second]
			  , qs.total_elapsed_time
			  , case when qs.execution_count > 0 then qs.total_elapsed_time / qs.execution_count else 0 end AS [avg_elapsed_time]
			  , qs.cached_time
		FROM    ['+@DatabaseName+'].sys.procedures AS p WITH ( NOLOCK )
				INNER JOIN ['+@DatabaseName+'].sys.dm_exec_procedure_stats AS qs WITH ( NOLOCK ) ON p.[object_id] = qs.[object_id]
				INNER JOIN ['+@DatabaseName+'].sys.schemas s on s.schema_id = p.schema_id
		WHERE   qs.database_id = DB_ID('''+@DatabaseName+''')
		ORDER BY qs.total_worker_time DESC
		
		'
		
		if @DatabaseName = 'master' or @version not like '%azure%'
			set @linkedserver = @server
		else 
			set @linkedserver = @server+'.'+@DatabaseName

		SET @SQL = 'with a as ('+@sql+')
		SELECT '+@serverid+', '+@databaseid+', a.*
			FROM a;'
		begin try
			insert into TopSql (Serverid,DatabaseId,SPName,TotalWorkerTime,AvgWorkerTime,execution_count,CallsPerSecond,total_elapsed_time,avg_elapsed_time,cached_time)
			exec dbo.spExec @sql
		end try
		begin catch
			print error_message()
			print @sql
		end catch
		FETCH NEXT FROM d_CURSOR INTO @databaseid, @databasename
	end
	close d_cursor
	deallocate d_cursor
	FETCH NEXT FROM T_CURSOR INTO @SERVER, @serverid, @version
END
CLOSE T_CURSOR
DEALLOCATE T_CURSOR



GO

CREATE proc [dbo].[spLoadTopWait] @serverid varchar(10)='0'
as

/***********************
	TopWait
************************/
if @serverid = '0'
	truncate table TopWait

declare @sql nvarchar(max), @SERVER VARCHAR(100), @DatabaseName varchar(100), @DatabaseId varchar(10)
DECLARE T_CURSOR CURSOR FAST_FORWARD FOR
	SELECT SERVERNAME, serverid FROM SERVERS s

OPEN T_CURSOR
FETCH NEXT FROM T_CURSOR INTO @SERVER, @serverid 
WHILE @@FETCH_STATUS=0
BEGIN
	if @SERVER = @@SERVERNAME
		set @SERVER = '.' 
	set @sql='
		SELECT TOP 40 wait_type, 
              max_wait_time_ms 
              wait_time_ms, 
              signal_wait_time_ms, 
              wait_time_ms - signal_wait_time_ms       AS resource_wait_time_ms, 
              100.0 * wait_time_ms / Sum(wait_time_ms)   OVER ( ) AS percent_total_waits, 
              100.0 * signal_wait_time_ms / Sum(signal_wait_time_ms) OVER ( )   AS percent_total_signal_waits, 
              100.0 * ( wait_time_ms - signal_wait_time_ms ) / Sum(wait_time_ms)  OVER ( ) AS percent_total_resource_waits 
		FROM   sys.dm_os_wait_stats 
		WHERE  wait_time_ms > 0 -- remove zero wait_time 
			   AND wait_type NOT IN -- filter out additional irrelevant waits 
				   ( 
					       ''BROKER_EVENTHANDLER'', ''BROKER_RECEIVE_WAITFOR'',
						   ''BROKER_TASK_STOP'', ''BROKER_TO_FLUSH'',
						   ''BROKER_TRANSMITTER'', ''CHECKPOINT_QUEUE'',
						   ''CHKPT'', ''CLR_AUTO_EVENT'',
						   ''CLR_MANUAL_EVENT'', ''CLR_SEMAPHORE'', 
						   -- Maybe uncomment these four if you have mirroring issues
						   ''DBMIRROR_DBM_EVENT'', ''DBMIRROR_EVENTS_QUEUE'',
						   ''DBMIRROR_WORKER_QUEUE'', ''DBMIRRORING_CMD'',
						   ''DIRTY_PAGE_POLL'', ''DISPATCHER_QUEUE_SEMAPHORE'',
						   ''EXECSYNC'', ''FSAGENT'',
						   ''FT_IFTS_SCHEDULER_IDLE_WAIT'', ''FT_IFTSHC_MUTEX'',
						   --Maybe uncomment these six if you have AG issues
						   ''HADR_CLUSAPI_CALL'', ''HADR_FILESTREAM_IOMGR_IOCOMPLETION'',
						   ''HADR_LOGCAPTURE_WAIT'', ''HADR_NOTIFICATION_DEQUEUE'',
						   ''HADR_TIMER_TASK'', ''HADR_WORK_QUEUE'',
						   ''KSOURCE_WAKEUP'', ''LAZYWRITER_SLEEP'',
						   ''LOGMGR_QUEUE'', ''MEMORY_ALLOCATION_EXT'',
						   ''ONDEMAND_TASK_QUEUE'',
						   ''PREEMPTIVE_XE_GETTARGETSTATE'',
						   ''PWAIT_ALL_COMPONENTS_INITIALIZED'',
						   ''PWAIT_DIRECTLOGCONSUMER_GETNEXT'',
						   ''QDS_PERSIST_TASK_MAIN_LOOP_SLEEP'', ''QDS_ASYNC_QUEUE'',
						   ''QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP'',
						   ''QDS_SHUTDOWN_QUEUE'', ''REDO_THREAD_PENDING_WORK'',
						   ''REQUEST_FOR_DEADLOCK_SEARCH'', ''RESOURCE_QUEUE'',
						   ''SERVER_IDLE_CHECK'', ''SLEEP_BPOOL_FLUSH'',
						   ''SLEEP_DBSTARTUP'', ''SLEEP_DCOMSTARTUP'',
						   ''SLEEP_MASTERDBREADY'', ''SLEEP_MASTERMDREADY'',
						   ''SLEEP_MASTERUPGRADED'', ''SLEEP_MSDBSTARTUP'',
						   ''SLEEP_SYSTEMTASK'', ''SLEEP_TASK'',
						   ''SLEEP_TEMPDBSTARTUP'', ''SNI_HTTP_ACCEPT'',
						   ''SP_SERVER_DIAGNOSTICS_SLEEP'', ''SQLTRACE_BUFFER_FLUSH'',
						   ''SQLTRACE_INCREMENTAL_FLUSH_SLEEP'',
						   ''SQLTRACE_WAIT_ENTRIES'', ''WAIT_FOR_RESULTS'',
						   ''WAITFOR'', ''WAITFOR_TASKSHUTDOWN'',
						   ''WAIT_XTP_RECOVERY'',
						   ''WAIT_XTP_HOST_WAIT'', ''WAIT_XTP_OFFLINE_CKPT_NEW_LOG'',
						   ''WAIT_XTP_CKPT_CLOSE'', ''XE_DISPATCHER_JOIN'',
						   ''XE_DISPATCHER_WAIT'', ''XE_TIMER_EVENT''
						   , ''CXPACKET'', ''PREEMPTIVE_XE_DISPATCHER'', ''SOS_WORK_DISPATCHER''
					 ) 
		ORDER  BY 7 DESC 
		'
	
		SET @sql = 'with a as ('+@sql+')
		SELECT '+@serverid+', a.*
			FROM a
			;'
		begin try
			insert into TopWait (Serverid, wait_type,wait_time_ms,signal_wait_time_ms,resource_wait_time_ms,percent_total_waits,percent_total_signal_waits,percent_total_resource_waits)
			exec dbo.spExec @sql
		end try
		begin catch
			print error_message()
			print @sql
		end catch

	FETCH NEXT FROM T_CURSOR INTO @SERVER, @serverid
END
CLOSE T_CURSOR
DEALLOCATE T_CURSOR

GO


CREATE proc [dbo].[spLoadVolumes]  @serverid int=0
as
if @serverid = '0'
	truncate table Volumes
else 
	delete from Volumes where serverid=@serverid


/**************
	Volumes
**************/
declare @sql nvarchar(max), @SERVER VARCHAR(100), @Version	varchar	(255)

DECLARE T_CURSOR CURSOR FAST_FORWARD FOR
	SELECT SERVERNAME, serverid, Version FROM SERVERS s
	where (Version like '%2008%' or Version like '%2012%' or Version like '%2014%' or Version like '%2016%' or Version like '%2017%' or Version like '%2019%')
	and version not like 'Microsoft SQL Azure%'

OPEN T_CURSOR
FETCH NEXT FROM T_CURSOR INTO @SERVER, @serverid, @Version 
WHILE @@FETCH_STATUS=0
BEGIN
	if @SERVER = @@SERVERNAME
		set @SERVER = '.' 
	set @sql='
		SELECT  distinct serverid = '+cast(@serverid as varchar)+'
			  , vs.volume_mount_point
			  , vs.total_bytes / 1024 / 1024 / 1024
			  , vs.available_bytes / 1024 / 1024 / 1024
			  , CAST(CAST(vs.available_bytes AS FLOAT) / CAST(vs.total_bytes AS FLOAT) AS DECIMAL(18, 3)) * 100 AS [Space Free %]
		FROM    sys.master_files AS f
				CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.file_id) AS vs
		
		   '
	/*
	SET @SQL = 'SELECT a.*	FROM OPENQUERY(['+@SERVER+'], 
		'''+replace(@sql, '''', '''''')+'''
		) AS a;'*/
	begin try
		insert into Volumes (ServerId, volume_mount_point, TotalGB,AvailableGB,PercentageFree)
		exec dbo.spExec @sql = @sql, @raiserror = 0
	end try
	begin catch
		print error_message()
		print @sql
	end catch
	FETCH NEXT FROM T_CURSOR INTO @SERVER, @serverid, @Version
END
CLOSE T_CURSOR
DEALLOCATE T_CURSOR

--select * from volumes


GO

CREATE TABLE [dbo].[SysConfigurations](
	[ServerName] [nvarchar](128) NULL,
	[name] [nvarchar](35) NOT NULL,
	[value] [sql_variant] NULL,
	[value_in_use] [sql_variant] NULL,
	[minimum] [sql_variant] NULL,
	[maximum] [sql_variant] NULL,
	[description] [nvarchar](255) NOT NULL,
	[is_dynamic] [bit] NOT NULL,
	[is_advanced] [bit] NOT NULL
) ON [PRIMARY]
GO

CREATE proc [dbo].[spLoadSysConfigurations]  
as
declare @sql nvarchar(max)

	set @sql='
		SELECT @@ServerName
			,	name
			,	value
			,	value_in_use
			,	minimum
			,	maximum
			,	description
			,	is_dynamic
			,	is_advanced
		FROM sys.configurations WITH (NOLOCK) ORDER BY name ;
	   '

	begin try
		insert into SysConfigurations (ServerName,name,value,value_in_use,minimum,maximum,description,is_dynamic,is_advanced)
		exec dbo.spExec @sql = @sql, @raiserror = 0
	end try
	begin catch
		print error_message()
		print @sql
	end catch


GO

create table dbo.LinkedServers (
	[ServerName] varchar(100), LinkedServer varchar(255), providername varchar(100), datasource varchar(255)
)
go

CREATE proc [dbo].[spLoadLinkedServers]  
as
declare @sql nvarchar(max)

	set @sql='
		select @@SERVERNAME, srvname, providername, datasource from master..sysservers
	   '
	begin try
		insert into LinkedServers ([ServerName], LinkedServer, providername, datasource)
		exec dbo.spExec @sql = @sql, @raiserror = 0
	end try
	begin catch
		print error_message()
		print @sql
	end catch


GO



CREATE view [dbo].[vwIndexUsage]
as
select s.ServerName, d.DatabaseName, do.[RowCount]
	, iu.*
	, dbo.InStringCount(cols+isnull(','+included,''), ',')+1 as ColCount
from IndexUsage iu
join Databases d on d.DatabaseId = iu.DatabaseId
join servers s on s.ServerId = iu.ServerId
left outer join DatabaseObjects do on do.DatabaseId = d.DatabaseId and do.SchemaName = iu.table_schema and iu.table_name = do.ObjectName
where allocation_desc ='IN_ROW_DATA'

GO

CREATE VIEW [dbo].[vwDatabases]
AS
SELECT s.ServerName
	,	m.datasource,	m.location
	--, s.ServerDescription
	, d.DatabaseName, d.DatabaseId, d.ServerId
	, df.DataMB, replace(format(df.DataMB,'N'),'.00','') DataMB_S 
	, df.LogMB
	, d.State_Desc
	, d.RecoveryModel
	, d.LogSizeKB
	, d.LogUsedKB
	, d.LogUsedPercentage
	, d.DBCompatibilityLevel
	, d.PageVerifyOption
	, d.is_auto_create_stats_on
	, d.is_auto_update_stats_on
	, d.is_auto_update_stats_async_on
	, d.is_parameterization_forced
	, d.snapshot_isolation_state_desc
	, d.is_read_committed_snapshot_on
	, d.is_auto_close_on
	, d.is_auto_shrink_on
	, d.target_recovery_time_in_seconds
	, d.Create_Date
	, d.is_published
	, d.is_subscribed
	, d.Collation
	, d.CachedSizeMbs
	, d.CPUTime
	, d.IOMbs
	, d.Is_Read_Only
	, d.delayed_durability_desc
	, d.containment_desc
	, d.is_cdc_enabled
	, d.is_broker_enabled
	, d.is_encrypted
	, d.is_memory_optimized_elevate_to_snapshot_on
	, d.AvailabilityGroup
	, d.PrimaryReplicaServerName
	, d.LocalReplicaRole
	, d.SynchronizationState
	, d.IsSuspended
	, d.IsJoined
	, d.SourceDatabaseName
	, d.owner
	, d.mirroring_state
	, d.mirroring_role
	, d.mirroring_safety_level
	, d.mirroring_partner
	, d.mirroring_partner_instance
	, d.mirroring_witness
	, d.mirroring_witness_state
	, d.mirroring_connection_timeout
	, d.mirroring_redo_queue
	, d.edition
	, d.service_objective
	, d.elastic_pool_name
	, fi.*
	, o.*
	, i.*
	, Columns
FROM servers s
JOIN databases d ON s.serverid=d.serverid
OUTER APPLY (
	SELECT SUM(CAST([rowCount] AS BIGINT)) Rows
		, SUM(CASE WHEN xtype='u' THEN 1 ELSE 0 END) Tables
		, SUM(case when xtype='u' and isnull([RowCount],0) = 0 then 1 else 0 end) Empty
		, SUM(case when xtype='u' and [RowCount] between 1 and 6 * power(10,6) then 1 else 0 end) Small --1 to 6 million
		, SUM(case when xtype='u' and [RowCount] between 6 * power(10,6) + 1 and 6 * power(10,7) then 1 else 0 end) Medium -- 6 to 60 million
		, SUM(case when xtype='u' and [RowCount] between 6 * power(10,7) + 1 and power(10,9) then 1 else 0 end) Large --60 million to 1 billion
		, SUM(case when xtype='u' and [RowCount] > power(10,9) then 1 else 0 end) VeryLarge --over 1 billion

		, SUM(CASE WHEN xtype='v' THEN 1 ELSE 0 END) Views
		, SUM(CASE WHEN xtype='p' THEN 1 ELSE 0 END) Procs
		, SUM(CASE WHEN xtype IN ('tf','fn') THEN 1 ELSE 0 END) Functions
	
		--select *
	FROM DatabaseObjects o
	WHERE o.DatabaseId = d.DatabaseId
) o
OUTER APPLY (
	SELECT SUM(1) Columns
	FROM [dbo].[DatabaseObjectColumns] oc
	WHERE oc.DatabaseId = d.DatabaseId 
) oc
OUTER APPLY (
	SELECT SUM(1) Files
		, COUNT(DISTINCT [filegroupname]) FileGroups
	FROM [dbo].[DatabaseFiles] fi
	WHERE fi.DatabaseId = d.DatabaseId 
) fi
OUTER APPLY (
	SELECT SUM(1) Indexes
		, SUM(i.data_size) Index_data_size
		, SUM(i.used_size) Index_used_size
		, sum(case when i.is_unique=1 then 1 else 0 end) UniqueIndexes
		, sum(case when isnull(i.included,'')<>'' then 1 else 0 end) IncludedColumnIndexes
		, sum(case when isnull(i.filter_definition,'')<>'' then 1 else 0 end) FilteredIndexes
		, sum(case when isnull(i.data_compression_desc ,'') like '%COLUMN STORE%' then 1 else 0 end) ColumnStores
	--select * 
	FROM IndexUsage i
	WHERE i.DatabaseId = d.DatabaseId
) i

OUTER APPLY (
	SELECT sum( case when filegroupname is not NULL then TotalMbs else 0 end) DataMb 
		, sum( case when filegroupname is NULL then TotalMbs else 0 end) LogMb
	FROM DatabaseFiles df
	WHERE df.databaseid = d.DatabaseId 
	) df
left outer join master..sysservers m on m.srvname = s.ServerName


GO


CREATE view [dbo].[vwDatabaseFiles]
as
select d.ServerName, d.DatabaseName, df.*
from databaseFiles df
join vwDatabases d on d.DatabaseId = df.DatabaseId

GO



CREATE view [dbo].[vwDatabaseObjects]
as
select d.ServerName, d.DatabaseName, do.SchemaName, do.ObjectName
	, do.Xtype
	, do.[RowCount], replace(format(do.[RowCount],'N'),'.00','') RowCount_S
	, do.ColCount, do.RowLength
	, do.ParentTable, do.ParentColumn
	, do.DatabaseObjectId, do.ServerId, do.DatabaseId
	, do.SQL_DATA_ACCESS, do.ROUTINE_DEFINITION, do.is_mspublished, do.is_rplpublished
	, do.is_rplsubscribed, do.is_disabled, do.parent_object_id, do.start_value, do.current_value, do.ParentSchema
	
	, isnull(i.index_name,'') PK, isnull(index_type,'') PKType, isnull(i.writes,0) writes, isnull(i.reads,0) reads, isnull(i.cols,'') PKCols
	, i2.*
	, c.*
from databaseobjects do
join vwDatabases d on d.DatabaseId = do.DatabaseId
outer apply (
	select top 1 * from vwIndexUsage i
	where i.DatabaseId = d.DatabaseId
	and i.table_schema = do.SchemaName
	and i.table_name = do.ObjectName
	and i.is_unique=1
	--and do.Xtype in ('U','V')
	order by i.index_id
) i
outer apply (
	select SUM(1) Indexes
		, SUM(i2.data_size) Index_data_size
		, SUM(i2.used_size) Index_used_size
		, sum(case when i2.is_unique=1 then 1 else 0 end) UniqueIndexes
		, sum(case when isnull(i2.included,'')<>'' then 1 else 0 end) IncludedColumnIndexes
		, sum(case when isnull(i2.filter_definition,'')<>'' then 1 else 0 end) FilteredIndexes
		, sum(case when isnull(i2.data_compression_desc ,'') like '%COLUMN STORE%' then 1 else 0 end) ColumnStores
	from vwIndexUsage i2
	where i2.DatabaseId = d.DatabaseId
	and i2.table_schema = do.SchemaName
	and i2.table_name = do.ObjectName
	--and do.Xtype in ('U','V')
) i2
outer apply (
	select count(*) ColumnsCount
		, sum(case when c.is_identity =1 then 1 else 0 end) HasIdentity
		, sum(case when c.is_computed =1 then 1 else 0 end) ComputedColumns
		, sum(case when CHARACTER_MAXIMUM_LENGTH=-1 then 1 else 0 end ) BlobColumns
	from DatabaseObjectColumns c
	where c.DatabaseObjectId = do.DatabaseObjectId
) c
where d.DatabaseName not in ('master','msdb','tempdb','model')
	
GO

CREATE view [dbo].[vwDatabaseObjectColumns]
as
select d.ServerName, d.DatabaseName
	, do.TABLE_CATALOG
	, do.TABLE_SCHEMA
	, do.TABLE_NAME
	, do.COLUMN_NAME
	, do.ORDINAL_POSITION
	, isnull(do.COLUMN_DEFAULT,'') COLUMN_DEFAULT
	, do.IS_NULLABLE
	, do.DATA_TYPE
	, do.CHARACTER_MAXIMUM_LENGTH
	, isnull(do.COLLATION_NAME,'') COLLATION_NAME
	, do.is_computed
	, do.is_identity
	, d.Xtype, d.[RowCount], d.RowCount_S
	, case when charindex(', '+do.COLUMN_NAME+',', ', '+pk.cols+',') > 0 then 1 else 0 end isKey
	, pk.index_name pkName, pk.cols pkCols
from databaseobjectColumns do
join vwDatabaseObjects d on d.DatabaseObjectId = do.DatabaseObjectId
outer apply (
	--get fisrt unique index and assume it the key
	select top 1 * from vwIndexUsage i
	where i.DatabaseId = do.DatabaseId
	and i.table_schema = do.TABLE_SCHEMA
	and i.table_name = do.TABLE_NAME
	and i.is_unique=1
	order by index_id 
) pk 

where d.DatabaseName not in ('master','msdb','tempdb','model')
go

CREATE VIEW [dbo].[vwAvailabilityGroups]
AS
SELECT s.ServerName
	, s.ServerDescription
	, s.Version
	, v.AvailabiityGroup
	, v.replica_server_name
	, v.IsPrimaryServer
	, v.ReadableSecondary
	, v.Synchronous
	, v.failover_mode_desc
FROM servers s
JOIN AvailabilityGroups v ON v.serverid=s.serverid
GO


CREATE view [dbo].[vwClusterNodes]
as
select s.ServerName
	, d.*
from servers s
join ClusterNodes
 d on s.serverid=d.serverid
GO
/****** Object:  View [dbo].[vwJobs]    Script Date: 2/26/2021 8:58:12 AM ******/


CREATE view [dbo].[vwJobs]
as
select  s.ServerName
	, s.ServerDescription
	, j.Jobname
	, j.Description
	, j.IsEnabled
	, j.ScheduleDscr
	, j.Operator
	, j.OperatorEnabled
	, j.Operator_email_address
	, j.Owner
	, j.JobStartStepName
	, j.IsScheduled
	, j.JobScheduleName
	, j.Frequency
	, j.Units
	, j.Active_start_date
	, j.Active_end_date
	, j.Run_Time
	, j.Created_Date
	, j.jobidentifier
--select *
from servers s
left join Jobs j on s.serverid=j.serverid


GO


create view [dbo].[vwTopSql]
as
select servername, databasename, t.* 
from topsql t 
join databases d on d.DatabaseId=t.DatabaseId
join servers s on s.ServerId = t.serverid

GO

create view [dbo].[vwTopWait]
as
select servername, t.* 
from topWait t 
join servers s on s.ServerId = t.serverid

go

create view [dbo].[vwVolumes]
as
select  s.ServerName
	, s.ServerDescription
	, v.*
from servers s
join Volumes v on v.serverid=s.serverid


GO


CREATE view [dbo].[vwServers]
as
select s.*
	,  SUBSTRING(version, 22,4) MajorVersion
	, sv.service_account
	, sv.last_startup_time
	, cn.NodeName
	, [LinkedServers]
	, d.*
	, v.*
	, ag.*
	, j.*
	, top_wait
	, TopSql
	, m.providername,	m.datasource,	m.location,	m.providerstring
from servers s
left outer join Services sv on sv.ServerId = s.ServerId and sv.servicename='SQL Server (MSSQLSERVER)'
left outer join ClusterNodes cn on cn.ServerId = s.ServerId and cn.is_current_owner=1

outer apply (
	select sum(1) Databases
		, sum(d.DataMB) DataMB
		, sum(d.LogMB) LogMB
		, sum(d.CachedSizeMbs) CachedSizeMbs
		, sum(d.CPUTime) CPUTime
	from [dbo].vwDatabases d 
	where d.ServerId = s.ServerId
)  d
outer apply (
	select sum(1) AvailabilityGroups
		, sum(cast(IsPrimaryServer as int)) PrimaryServer
		, sum(1-cast(IsPrimaryServer as int)) ReplicaServer
	from [dbo].[AvailabilityGroups] ag 
	where ag.ServerId = s.ServerId
)  v
outer apply (
	select sum(1) Volumes
		, sum(v.TotalGB) TotalGB
		, sum(v.AvailableGB) AvailableGB
	from [dbo].Volumes v 
	where v.ServerId = s.ServerId
)  ag
outer apply (
	select sum(1) Jobs
	from [dbo].Jobs j 
	where j.ServerId = s.ServerId
)  j

outer apply (
	select top 1 [wait_type] top_wait
	from [dbo].[TopWait] w
	where w.ServerId = s.ServerId
	order by [wait_time_ms] desc
)  W
outer apply (
	select top 1 SPName TopSql
	from [dbo].[TopSql] ts
	where ts.ServerId = s.ServerId
	order by [TotalWorkerTime] desc
)  ts
outer apply (
	select sum(1) AvailabilityGroups
		, sum(case when [IsPrimaryServer]= 1 then 1 else 0 end) PrimaryAvailabilityGroups
		, sum(case when [IsPrimaryServer]= 0 then 1 else 0 end) ReplicaAvailabilityGroups
	from [dbo].[AvailabilityGroups] ags
	where ags.ServerId = s.ServerId
)  Ags
left outer join master..sysservers m on m.srvname = s.ServerName
outer apply (
	select sum(1) [LinkedServers]
	from [dbo].[LinkedServers] L 
	where l.ServerName = s.ServerName
)  l

GO




CREATE proc [dbo].[spLoadIncompatibilities] @serverid int=0
as
set nocount on

--routines with linked servers
if OBJECT_ID('dbo.Synapse_XServerRoutine') is not null
	drop table Synapse_XServerRoutine
select x.LinkedServer,
	o.DatabaseName, o.xtype, o.SchemaName, o.ObjectName, o.routine_definition
into dbo.Synapse_XServerRoutine
from vwDatabaseObjects o
cross apply (select top 1 * from LinkedServers x
	where CHARINDEX(LinkedServer+'.', routine_definition) > 0
	or CHARINDEX(LinkedServer+'].', routine_definition) > 0
	) x
where routine_definition is not null
order by 1, 2, 3, 4, 5 

--routines with cross database calls
if OBJECT_ID('dbo.Synapse_XDatabaseRoutine') is not null
	drop table Synapse_XDatabaseRoutine
select x.DatabaseName as xDatabaseName, 
	o.DatabaseName, o.xtype, o.SchemaName, o.ObjectName, o.routine_definition
into dbo.Synapse_XDatabaseRoutine
from vwDatabaseObjects o
cross apply (select top 1 * from Databases x
	where CHARINDEX(DatabaseName+'.', routine_definition) > 0 
		or  CHARINDEX(DatabaseName+'].', routine_definition) > 0
	) x
where routine_definition is not null
and x.DatabaseName <> o.DatabaseName
order by 1, 2, 3, 4, 5

--incompatible routines
if OBJECT_ID('dbo.Synapse_IncompatibleRoutineType') is not null
	drop table Synapse_IncompatibleRoutineType
select o.DatabaseName, o.xtype, 
  case 
	when o.xtype='AF' then 'Aggregate function (CLR)'
	when o.xtype='C'  then 'CHECK constraint'
	when o.xtype='D'  then 'Default or DEFAULT constraint'
	when o.xtype='F'  then 'FOREIGN KEY constraint'
	when o.xtype='L'  then 'Log'
	when o.xtype='FN' then 'Scalar function'
	when o.xtype='FS' then 'Assembly (CLR) scalar-function'
	when o.xtype='FT' then 'Assembly (CLR) table-valued function'
	when o.xtype='IF' then 'In-lined table-function'
	when o.xtype='IT' then 'Internal table'
	when o.xtype='P'  then 'Stored procedure'
	when o.xtype='PC' then 'Assembly (CLR) stored-procedure'
	when o.xtype='PK' then 'PRIMARY KEY constraint'
	when o.xtype='RF' then 'Replication filter stored procedure'
	when o.xtype='S'  then 'System table'
	when o.xtype='SN' then 'Synonym'
	when o.xtype='SQ' then 'Service queue'
	when o.xtype='TA' then 'Assembly (CLR) DML trigger'
	when o.xtype='TF' then 'Table function'
	when o.xtype='TR' then 'SQL DML Trigger'
	when o.xtype='TT' then 'Table type'
	when o.xtype='U'  then 'User table'
	when o.xtype='UQ' then 'UNIQUE constraint'
	when o.xtype='V'  then 'View'
	when o.xtype='X'  then 'Extended stored procedure'
	end as TypeDesc
	, o.SchemaName, o.ObjectName, o.routine_definition
into dbo.Synapse_IncompatibleRoutineType
from vwDatabaseObjects o
where routine_definition is not null
and [Xtype] in ('tr','tt','x','uq','af','fs','ft','it','uq','F')
order by 1, 2, 3, 4, 5

if OBJECT_ID('dbo.Synapse_IncompatibleRoutine') is not null
	drop table Synapse_IncompatibleRoutine
select o.DatabaseName, o.xtype, o.SchemaName, o.ObjectName, o.routine_definition,
	case when routine_definition like '%for xml%' then 1 else 0 end as UsesForXML,
	case when routine_definition like '%declare%cursor%' then 1 else 0 end as UsesCursor,
	case when xtype in ('tr','tt','x','uq','af','fs','ft','it','uq','F') then 1 else 0 end IncompatibleType
into dbo.Synapse_IncompatibleRoutine
from vwDatabaseObjects o
where routine_definition like '%for xml%'
or routine_definition like '%declare%cursor%'
order by 1, 2, 3, 4, 5

if OBJECT_ID('dbo.Synapse_IncompatibleColumn') is not null
	drop table Synapse_IncompatibleColumn
select databasename, table_schema, table_catalog,  table_name, c.COLUMN_NAME, c.ORDINAL_POSITION, c.IS_NULLABLE, c.COLLATION_NAME, c.CHARACTER_MAXIMUM_LENGTH, c.DATA_TYPE, c.[RowCount] TableRowCount
into dbo.Synapse_IncompatibleColumn
--select *
from vwDatabaseObjectColumns c
where data_type in ('geography', 'geometry', 'hierarchyid', 'sql_variant', 'xml', 'image')
order by 1,2,3,4,5

if OBJECT_ID('dbo.Synapse_ComputedColumn') is not null
	drop table Synapse_ComputedColumn
select databasename, table_schema, table_catalog,  table_name, c.COLUMN_NAME, c.ORDINAL_POSITION, c.IS_NULLABLE, c.COLLATION_NAME, c.CHARACTER_MAXIMUM_LENGTH, c.DATA_TYPE, c.[RowCount] TableRowCount
into dbo.Synapse_ComputedColumn
--select *
from vwDatabaseObjectColumns c
where is_computed=1
order by 1,2,3,4,5

if OBJECT_ID('dbo.Synapse_LargeTextColumn') is not null
	drop table Synapse_LargeTextColumn
select databasename, table_schema, table_catalog,  table_name, c.COLUMN_NAME, c.ORDINAL_POSITION, c.IS_NULLABLE, c.COLLATION_NAME, c.CHARACTER_MAXIMUM_LENGTH, c.DATA_TYPE, c.[RowCount] TableRowCount
into dbo.Synapse_LargeTextColumn
--select *
from vwDatabaseObjectColumns c
where data_type in ( 'text', 'ntext', 'varchar(max)')
or is_computed=1
order by 1,2,3,4,5

--invalid defaults
if OBJECT_ID('dbo.Synapse_InvalidDefaults') is not null
	drop table Synapse_InvalidDefaults
select databasename, table_schema, table_catalog,  table_name, c.COLUMN_NAME, c.ORDINAL_POSITION, c.IS_NULLABLE, c.column_default, c.DATA_TYPE 
into dbo.Synapse_InvalidDefaults
from vwDatabaseObjectColumns c
where column_default like '%()%'

go


CREATE proc [dbo].[spLoad] 
as
set nocount on

exec spCleanup

delete from [Servers]

INSERT INTO [dbo].[Servers] ([ServerName],[IsActive],Version )
     VALUES  (@@servername, 1, @@VERSION)
	 	 
exec spLoadServers 
exec spLoadLinkedServers
exec spLoadServices 
exec spLoadClusterNodes 
exec [spLoadAvailabilityGroups]  
exec spLoadSysConfigurations
exec spLoadDatabases 

exec spLoadTopSql 
exec spLoadTopWait 
exec spLoadVolumes 
exec spLoadJobs 
exec spLoadJobSteps 

exec spLoadDataBaseFiles 
exec spLoadDataBaseObjects 
exec [spLoadDataBaseObjectColums] 
exec [spLoadIndexUsage] 

exec [spLoadIncompatibilities]

go


CREATE proc [dbo].[spReturn]
as
--instance
select ServerName
	, WindowsRelease
	, CreatedDate
	, Version
	, Edition
	, ProductLevel
	, Collation
	, LogicalCPUCount
	, HyperthreadRatio
	, PhysicalCPUCount
	, PhysicalMemoryMB
	, VMType
	, Build
	, resource_governor_enabled_functions
	, MajorVersion
	, service_account
	, last_startup_time
	, LinkedServers
	, Databases
	, DataMB
	, LogMB
	, CachedSizeMbs
	, CPUTime
	, AvailabilityGroups
	, Volumes
	, TotalGB
	, AvailableGB
	, Jobs
	, top_wait
	, TopSql
	, providername
from vwServers

--jobs
select Job_Name, Enabled,	ScheduleDscr, Step_Name, Database_Name, Command
from JobSteps

--wait stats
select wait_type
	, percent_total_waits
	, percent_total_signal_waits
	, percent_total_resource_waits
from [vwTopWait]
order by 2 desc

--top sql
select d.DatabaseName, SPName, TotalWorkerTime, execution_count, AvgWorkerTime
from TopSql t
join Databases d on t.DatabaseId = d.DatabaseId
order by TotalWorkerTime desc

--databases
select d.DatabaseName
	, isnull(DataMB,0)DataMB
	, isnull(Files, 0) Files
	, isnull(Tables,0) Tables

	, isnull(Empty,0) Empty
	, isnull(Small,0) Small
	, isnull(Medium,0) Medium
	, isnull(Large,0) Large
	, isnull(VeryLarge,0) VeryLarge

	, isnull(Columns,0) Columns
	, isnull(Rows,0) Rows
	, isnull(Views,0) Views
	, isnull(Procs,0) Procs
	, isnull(Functions,0) Functions
	, isnull(Indexes,0) Indexes
	, isnull(ColumnStores,0) ColumnStores

	, isnull(UniqueIndexes,0) UniqueIndexes
	, isnull(IncludedColumnIndexes,0) IncludedColumnIndexes
	, isnull(LargeTextColumn,0) LargeTextColumns
	, isnull(IncompatibleDefault,0) IncompatibleDefaults

	, isnull(FilteredIndexes,0) FilteredIndexes
	, isnull(ComputedColumn,0) ComputedColumns
	, isnull(XServerRoutines,0) XServerRoutines
	, isnull(LinkedServers,'') LinkedServers
	, isnull(XOutRoutines,0) XOutRoutines
	, isnull(XOutDbs,'') XOutDbs
	, isnull(XInRoutines,0) XInRoutines
	, isnull(XInDbs,'') XInDbs
	, isnull(UsesForXML,0) UsesForXML
	, isnull(UsesCursor,0) UsesCursor
	, isnull(IncompatibleColumn,0) IncompatibleColumns
	, isnull(IncompatibleRoutinesByType,0) IncompatibleRoutinesByType
	, isnull(Sequences,0) Sequences
from vwDatabases d
outer apply (
	select count(*) IncompatibleColumn 
	from [dbo].[Synapse_IncompatibleColumn] ic
	where ic.DatabaseName=d.DatabaseName
	) ic
outer apply (
	select count(*) ComputedColumn from [dbo].[Synapse_ComputedColumn] cc
	where cc.DatabaseName=d.DatabaseName
	)  cc
outer apply (
	select count(*) LargeTextColumn from [dbo].[Synapse_LargeTextColumn] lt
	where lt.DatabaseName=d.DatabaseName
	)  lt
outer apply (
	select count(*) IncompatibleDefault
	from [dbo].Synapse_InvalidDefaults id
	where id.DatabaseName=d.DatabaseName
	)  id
outer apply (
	select sum(UsesForXML) UsesForXML,
		sum(UsesCursor) UsesCursor
	from [dbo].[Synapse_IncompatibleRoutine] x
	where x.DatabaseName=d.DatabaseName
	)  x
outer apply (
	select count(*) IncompatibleRoutinesByType
	from [dbo].[Synapse_IncompatibleRoutineType] ir
	where ir.DatabaseName=d.DatabaseName
	)  ir

left join (
	select DatabaseName, sum(cnt) XServerRoutines, string_agg(LinkedServer,',') LinkedServers
	from (
		select distinct DatabaseName, count(*) cnt, LinkedServer  
		from [dbo].[Synapse_XServerRoutine] xs
		group by  DatabaseName, LinkedServer
		) xs
	group by DatabaseName
	)  xs on xs.DatabaseName=d.DatabaseName 

left join (
	select DatabaseName, sum(cnt) XOutRoutines, string_agg(xDatabaseName,',') XOutDbs
	from (
		select distinct DatabaseName, count(*) cnt, xDatabaseName  
		from [dbo].[Synapse_XDatabaseRoutine] xo
		where xDatabaseName <> 'tempdb'
		group by DatabaseName, xDatabaseName
		) xo
	group by DatabaseName
	)  xo on xo.DatabaseName=d.DatabaseName 

left join (
	select  xDatabaseName, sum(cnt) XInRoutines, string_agg(DatabaseName,',') XInDbs
	from (
		select distinct  xDatabaseName, count(*) cnt, DatabaseName  
		from [dbo].[Synapse_XDatabaseRoutine] xi
		group by  xDatabaseName, DatabaseName
		) xi
	group by  xDatabaseName
	)  xi on xi.xDatabaseName=d.DatabaseName 

outer apply( 
	select count(*) Sequences
	from sequences s
	where d.databaseid= s.databaseid
) seq
where d.databasename not in ('msdb','tempdb','master','model')
order by 1

--tables
select 
	  DatabaseName
	, SchemaName
	, ObjectName
	, [RowCount]
	, RowLength
	, PK
	, PKType
	, writes
	, reads
	, PKCols
	, Indexes
	, Index_data_size
	, Index_used_size
	, ColumnStores
	, ColumnsCount
	, HasIdentity

	, ComputedColumns
	, UniqueIndexes

	, IncludedColumnIndexes
	, FilteredIndexes
	, BlobColumns
from vwDatabaseObjects o
where xtype='u'
order by 1,2,3

--columns
select DatabaseName
	, TABLE_SCHEMA SchemaName
	, TABLE_NAME TableName
	, ORDINAL_POSITION
	, COLUMN_NAME 
	, COLUMN_DEFAULT
	, IS_NULLABLE
	, DATA_TYPE
	, CHARACTER_MAXIMUM_LENGTH
	, COLLATION_NAME
	, is_computed
	, is_identity
	, Xtype
	, isKey 
	, case when is_computed=1 then 'Is Computed'
		when xtype in ('geography', 'geometry', 'hierarchyid', 'sql_variant', 'xml', 'image') then 'Incompatible Type'
		when COLUMN_DEFAULT like '%()%' then 'Incompatible Default'
		when CHARACTER_MAXIMUM_LENGTH = -1 then  'Cant be Column Compressed'
		else ''
	end Comment
from vwDatabaseObjectColumns
order by 1,2,3,4

--Indexes
select d.DatabaseName
	, table_schema
	, table_name
	, isnull(index_name,'') index_name
	, data_space
	, allocation_desc
	, object_type
	, index_type
	, is_disabled
	, database_file
	, size_mbs
	, used_size
	, data_size
	, writes
	, reads
	, index_id
	, fill_factor
	, isnull(cols,'') columns
	, is_unique
	, isnull(included,'') included
	, isnull(filter_definition,'') filter_definition
	, data_compression_desc	
from IndexUsage iu
join Databases d on d.DatabaseId = iu.DatabaseId
order by 1, 2,3,4,5,6

--Routines
select o.DatabaseName
	, o.SchemaName
	, o.Xtype
	, case 
		when o.xtype='AF' then 'Aggregate function (CLR)'
		when o.xtype='C'  then 'CHECK constraint'
		when o.xtype='D'  then 'Default or DEFAULT constraint'
		when o.xtype='F'  then 'FOREIGN KEY constraint'
		when o.xtype='L'  then 'Log'
		when o.xtype='FN' then 'Scalar function'
		when o.xtype='FS' then 'Assembly (CLR) scalar-function'
		when o.xtype='FT' then 'Assembly (CLR) table-valued function'
		when o.xtype='IF' then 'In-lined table-function'
		when o.xtype='IT' then 'Internal table'
		when o.xtype='P'  then 'Stored procedure'
		when o.xtype='PC' then 'Assembly (CLR) stored-procedure'
		when o.xtype='PK' then 'PRIMARY KEY constraint'
		when o.xtype='RF' then 'Replication filter stored procedure'
		when o.xtype='S'  then 'System table'
		when o.xtype='SN' then 'Synonym'
		when o.xtype='SQ' then 'Service queue'
		when o.xtype='TA' then 'Assembly (CLR) DML trigger'
		when o.xtype='TF' then 'Table function'
		when o.xtype='TR' then 'SQL DML Trigger'
		when o.xtype='TT' then 'Table type'
		when o.xtype='U'  then 'User table'
		when o.xtype='UQ' then 'UNIQUE constraint'
		when o.xtype='V'  then 'View'
		when o.xtype='X'  then 'Extended stored procedure'
	end as TypeDesc
	, o.ObjectName
	, isnull(o.SQL_DATA_ACCESS,'') SQL_DATA_ACCESS
	, isnull(LinkedServers,'') LinkedServers
	, isnull(XOutDbs,'') XOutDbs
	, case when o.routine_definition like '%for xml%' then 1 else 0 end as UsesForXML
	, case when o.routine_definition like '%declare%cursor%' then 1 else 0 end as UsesCursor	
	, case when xtype in ('tr','tt','x','uq','af','fs','ft','it','uq','F') then 1 else 0 end as IncompatibleType
	, o.ROUTINE_DEFINITION
from vwDatabaseObjects o

left join (
	select DatabaseName, [SchemaName], [ObjectName], string_agg(LinkedServer,',') LinkedServers
	from (
		select distinct DatabaseName, [SchemaName], [ObjectName], LinkedServer  
		from [dbo].[Synapse_XServerRoutine] xs
		group by  DatabaseName, [SchemaName], [ObjectName], LinkedServer
		) xs
	group by DatabaseName, [SchemaName], [ObjectName]
	)  xs on xs.DatabaseName=o.DatabaseName and xs.[SchemaName] = o.[SchemaName] and xs.[ObjectName] = o.[ObjectName]

left join (
	select DatabaseName, [SchemaName], [ObjectName],  string_agg(xDatabaseName,',') XOutDbs
	from (
		select distinct DatabaseName, [SchemaName], [ObjectName], xDatabaseName  
		from [dbo].[Synapse_XDatabaseRoutine] xo
		where xDatabaseName <> 'tempdb'
		group by DatabaseName, [SchemaName], [ObjectName], xDatabaseName
		) xo
	group by DatabaseName, [SchemaName], [ObjectName]
	)  xo on xo.DatabaseName=o.DatabaseName and xo.[SchemaName] = o.[SchemaName] and xo.[ObjectName] = o.[ObjectName]

where xtype not in ('u')
order by 1,2,3,4,5

select d.DatabaseName
	, s.SequenceName
	, s.ParentTable
	, s.ParentColumn
from sequences s
join databases d on s.databaseid= d.databaseid


go


