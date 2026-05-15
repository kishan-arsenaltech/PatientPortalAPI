-- ============================================================
-- PatientPortal Portal — STRUCTURE ONLY SCRIPT
-- Microsoft SQL Server 2022
-- Generated for: ASP.NET Core (.NET 9) + Angular 21 backend
-- ============================================================
-- EXECUTION ORDER:
--   1. Database + schemas
--   2. Lookup / reference tables
--   3. Core platform tables (auth, users, orgs, audit)
--   4. Patient + provider tables
--   5. Clinical / adherence tables
--   6. Intake / referral tables
--   7. Billing / claims / audit-share tables
--   8. Notification + workflow + job tables
--   9. Views
--  10. Stored procedures + functions
--  11. Triggers
-- ============================================================

USE master;
GO

-- ============================================================
-- 1. DATABASE
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = N'PatientPortal')
BEGIN
    CREATE DATABASE PatientPortal
    COLLATE SQL_Latin1_General_CP1_CI_AS;
END;
GO

USE PatientPortal;
GO

-- ============================================================
-- 2. SCHEMAS
-- ============================================================
-- auth   : authentication, sessions, tokens, MFA
-- core   : users, organizations, tenants, RBAC
-- patient: patient demographics, contacts, medical history
-- clinical: adherence, care plans, medications, orders
-- intake : referrals, intake forms, questionnaires
-- billing: claims, invoices, payments, insurance, refunds
-- audit  : audit-share workflows, HIPAA logs, access logs
-- notify : notifications, inbox, email/SMS templates
-- workflow: tasks, workflow engine, background jobs
-- report : reporting views and KPI aggregation tables
-- cfg    : feature flags, configuration, lookups

DECLARE @schemas TABLE (SchemaName SYSNAME);
INSERT INTO @schemas VALUES
('auth'),('core'),('patient'),('clinical'),
('intake'),('billing'),('audit'),
('notify'),('workflow'),('report'),('cfg');

DECLARE @s SYSNAME;
DECLARE sc CURSOR LOCAL FAST_FORWARD FOR SELECT SchemaName FROM @schemas;
OPEN sc; FETCH NEXT FROM sc INTO @s;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = @s)
        EXEC('CREATE SCHEMA [' + @s + ']');
    FETCH NEXT FROM sc INTO @s;
END;
CLOSE sc; DEALLOCATE sc;
GO

-- ============================================================
-- 3. LOOKUP / REFERENCE TABLES  (cfg schema)
-- ============================================================

-- 3.1  cfg.LookupType — master category list for all lookup values
CREATE TABLE cfg.LookupType (
    LookupTypeID    SMALLINT        NOT NULL IDENTITY(1,1),
    TypeCode        VARCHAR(60)     NOT NULL,   -- e.g. 'GENDER', 'CLAIM_STATUS'
    TypeLabel       NVARCHAR(120)   NOT NULL,
    IsActive        BIT             NOT NULL DEFAULT 1,
    CONSTRAINT PK_LookupType PRIMARY KEY CLUSTERED (LookupTypeID),
    CONSTRAINT UQ_LookupType_TypeCode UNIQUE (TypeCode)
);
GO

-- 3.2  cfg.Lookup — all enumerated values in the system
CREATE TABLE cfg.Lookup (
    LookupID        INT             NOT NULL IDENTITY(1,1),
    LookupTypeID    SMALLINT        NOT NULL,
    Code            VARCHAR(60)     NOT NULL,
    Label           NVARCHAR(200)   NOT NULL,
    ShortLabel      NVARCHAR(80)    NULL,
    SortOrder       SMALLINT        NOT NULL DEFAULT 0,
    IsActive        BIT             NOT NULL DEFAULT 1,
    Metadata        NVARCHAR(MAX)   NULL,       -- JSON for extra props per type
    CONSTRAINT PK_Lookup PRIMARY KEY CLUSTERED (LookupID),
    CONSTRAINT UQ_Lookup_TypeCode UNIQUE (LookupTypeID, Code),
    CONSTRAINT FK_Lookup_LookupType FOREIGN KEY (LookupTypeID)
        REFERENCES cfg.LookupType (LookupTypeID)
);
CREATE NONCLUSTERED INDEX IX_Lookup_TypeCode
    ON cfg.Lookup (LookupTypeID, Code) INCLUDE (Label, IsActive);
GO

-- 3.3  cfg.FeatureFlag
CREATE TABLE cfg.FeatureFlag (
    FeatureFlagID   INT             NOT NULL IDENTITY(1,1),
    FlagKey         VARCHAR(100)    NOT NULL,
    FlagLabel       NVARCHAR(200)   NOT NULL,
    IsEnabled       BIT             NOT NULL DEFAULT 0,
    TenantOverrides NVARCHAR(MAX)   NULL,   -- JSON { "tenantId": true/false }
    UserOverrides   NVARCHAR(MAX)   NULL,
    CreatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_FeatureFlag PRIMARY KEY CLUSTERED (FeatureFlagID),
    CONSTRAINT UQ_FeatureFlag_Key UNIQUE (FlagKey)
);
GO

-- 3.4  cfg.AppSetting
CREATE TABLE cfg.AppSetting (
    SettingID       INT             NOT NULL IDENTITY(1,1),
    TenantID        UNIQUEIDENTIFIER NULL,  -- NULL = system-wide
    SettingKey      VARCHAR(120)    NOT NULL,
    SettingValue    NVARCHAR(MAX)   NOT NULL,
    DataType        VARCHAR(20)     NOT NULL DEFAULT 'string', -- string|int|bool|json
    IsEncrypted     BIT             NOT NULL DEFAULT 0,
    UpdatedByUserID UNIQUEIDENTIFIER NULL,
    UpdatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_AppSetting PRIMARY KEY CLUSTERED (SettingID),
    CONSTRAINT UQ_AppSetting_TenantKey UNIQUE (TenantID, SettingKey)
);
GO

-- ============================================================
-- 4. CORE PLATFORM  (core + auth schemas)
-- ============================================================

-- 4.1  core.Tenant — multi-tenant root
CREATE TABLE core.Tenant (
    TenantID        UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantCode      VARCHAR(40)     NOT NULL,
    TenantName      NVARCHAR(200)   NOT NULL,
    PlanTier        VARCHAR(30)     NOT NULL DEFAULT 'enterprise',
    IsActive        BIT             NOT NULL DEFAULT 1,
    CreatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    RowVersion      ROWVERSION      NOT NULL,
    DeletedAt       DATETIMEOFFSET  NULL,
    CONSTRAINT PK_Tenant PRIMARY KEY CLUSTERED (TenantID),
    CONSTRAINT UQ_Tenant_Code UNIQUE (TenantCode)
);
GO

-- 4.2  core.Organization — branch hierarchy under tenant
CREATE TABLE core.Organization (
    OrganizationID  UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantID        UNIQUEIDENTIFIER NOT NULL,
    ParentOrgID     UNIQUEIDENTIFIER NULL,
    OrgCode         VARCHAR(40)     NOT NULL,
    OrgName         NVARCHAR(200)   NOT NULL,
    OrgType         VARCHAR(30)     NOT NULL, -- 'CORPORATE','REGION','BRANCH'
    AddressLine1    NVARCHAR(200)   NULL,
    AddressLine2    NVARCHAR(200)   NULL,
    City            NVARCHAR(100)   NULL,
    StateCode       CHAR(2)         NULL,
    ZipCode         VARCHAR(10)     NULL,
    Phone           VARCHAR(20)     NULL,
    IsActive        BIT             NOT NULL DEFAULT 1,
    CreatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    RowVersion      ROWVERSION      NOT NULL,
    DeletedAt       DATETIMEOFFSET  NULL,
    CONSTRAINT PK_Organization PRIMARY KEY CLUSTERED (OrganizationID),
    CONSTRAINT UQ_Organization_TenantCode UNIQUE (TenantID, OrgCode),
    CONSTRAINT FK_Organization_Tenant FOREIGN KEY (TenantID)
        REFERENCES core.Tenant (TenantID),
    CONSTRAINT FK_Organization_Parent FOREIGN KEY (ParentOrgID)
        REFERENCES core.Organization (OrganizationID)
);
CREATE NONCLUSTERED INDEX IX_Org_TenantParent
    ON core.Organization (TenantID, ParentOrgID) WHERE DeletedAt IS NULL;
GO

-- 4.3  core.Role — RBAC roles
CREATE TABLE core.Role (
    RoleID          INT             NOT NULL IDENTITY(1,1),
    TenantID        UNIQUEIDENTIFIER NULL,   -- NULL = system role
    RoleCode        VARCHAR(60)     NOT NULL,
    RoleName        NVARCHAR(120)   NOT NULL,
    Description     NVARCHAR(500)   NULL,
    IsSystem        BIT             NOT NULL DEFAULT 0,
    IsActive        BIT             NOT NULL DEFAULT 1,
    CreatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_Role PRIMARY KEY CLUSTERED (RoleID),
    CONSTRAINT UQ_Role_TenantCode UNIQUE (TenantID, RoleCode)
);
GO

-- 4.4  core.Permission
CREATE TABLE core.Permission (
    PermissionID    INT             NOT NULL IDENTITY(1,1),
    PermissionCode  VARCHAR(100)    NOT NULL,  -- e.g. 'patients.view'
    Module          VARCHAR(60)     NOT NULL,  -- 'PATIENT','BILLING', etc.
    Action          VARCHAR(30)     NOT NULL,  -- 'view','create','edit','delete'
    Description     NVARCHAR(300)   NULL,
    CONSTRAINT PK_Permission PRIMARY KEY CLUSTERED (PermissionID),
    CONSTRAINT UQ_Permission_Code UNIQUE (PermissionCode)
);
GO

-- 4.5  core.RolePermission
CREATE TABLE core.RolePermission (
    RoleID          INT             NOT NULL,
    PermissionID    INT             NOT NULL,
    CONSTRAINT PK_RolePermission PRIMARY KEY CLUSTERED (RoleID, PermissionID),
    CONSTRAINT FK_RolePerm_Role FOREIGN KEY (RoleID) REFERENCES core.Role (RoleID),
    CONSTRAINT FK_RolePerm_Perm FOREIGN KEY (PermissionID) REFERENCES core.Permission (PermissionID)
);
GO

-- 4.6  core.User
CREATE TABLE core.Users (
    UserID          UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantID        UNIQUEIDENTIFIER NOT NULL,
    OrganizationID  UNIQUEIDENTIFIER NULL,
    Username        NVARCHAR(100)   NOT NULL,
    Email           NVARCHAR(200)   NOT NULL,
    DisplayName     NVARCHAR(200)   NOT NULL,
    FirstName       NVARCHAR(100)   NOT NULL,
    LastName        NVARCHAR(100)   NOT NULL,
    AvatarUrl       NVARCHAR(500)   NULL,
    JobTitle        NVARCHAR(150)   NULL,
    Department      NVARCHAR(100)   NULL,
    IsActive        BIT             NOT NULL DEFAULT 1,
    IsSystemUser    BIT             NOT NULL DEFAULT 0,
    MustChangePassword BIT          NOT NULL DEFAULT 0,
    LastLoginAt     DATETIMEOFFSET  NULL,
    CreatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    RowVersion      ROWVERSION      NOT NULL,
    DeletedAt       DATETIMEOFFSET  NULL,
    CONSTRAINT PK_User PRIMARY KEY CLUSTERED (UserID),
    CONSTRAINT UQ_User_Email UNIQUE (TenantID, Email),
    CONSTRAINT UQ_User_Username UNIQUE (TenantID, Username),
    CONSTRAINT FK_User_Tenant FOREIGN KEY (TenantID) REFERENCES core.Tenant (TenantID),
    CONSTRAINT FK_User_Org FOREIGN KEY (OrganizationID) REFERENCES core.Organization (OrganizationID)
);
CREATE NONCLUSTERED INDEX IX_User_TenantEmail
    ON core.Users (TenantID, Email) WHERE DeletedAt IS NULL;
GO

-- 4.7  core.UserRole
CREATE TABLE core.UserRole (
    UserID          UNIQUEIDENTIFIER NOT NULL,
    RoleID          INT             NOT NULL,
    OrganizationID  UNIQUEIDENTIFIER NULL,   -- scope role to a branch
    GrantedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    GrantedByUserID UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_UserRole PRIMARY KEY CLUSTERED (UserID, RoleID),
    CONSTRAINT FK_UserRole_User FOREIGN KEY (UserID) REFERENCES core.Users (UserID),
    CONSTRAINT FK_UserRole_Role FOREIGN KEY (RoleID) REFERENCES core.Role (RoleID)
);
GO

-- 4.8  auth.Credential — hashed passwords + SSO info
CREATE TABLE auth.Credential (
    CredentialID    UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    UserID          UNIQUEIDENTIFIER NOT NULL,
    PasswordHash    NVARCHAR(500)   NULL,   -- bcrypt/argon2 hash
    PasswordSalt    NVARCHAR(100)   NULL,
    SsoProvider     VARCHAR(30)     NULL,   -- 'MICROSOFT','OKTA',etc.
    SsoSubject      NVARCHAR(300)   NULL,   -- external identity token sub
    LastChangedAt   DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    ExpiresAt       DATETIMEOFFSET  NULL,
    IsLocked        BIT             NOT NULL DEFAULT 0,
    FailedAttempts  TINYINT         NOT NULL DEFAULT 0,
    LockedUntil     DATETIMEOFFSET  NULL,
    CONSTRAINT PK_Credential PRIMARY KEY CLUSTERED (CredentialID),
    CONSTRAINT UQ_Credential_User UNIQUE (UserID),
    CONSTRAINT FK_Credential_User FOREIGN KEY (UserID) REFERENCES core.Users (UserID)
);
GO

-- 4.9  auth.Session
CREATE TABLE auth.Session (
    SessionID       UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    UserID          UNIQUEIDENTIFIER NOT NULL,
    RefreshToken    NVARCHAR(500)   NOT NULL,
    AccessTokenJti  NVARCHAR(100)   NOT NULL,   -- JWT ID for revocation
    DeviceInfo      NVARCHAR(500)   NULL,
    IpAddress       VARCHAR(45)     NULL,
    CreatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    ExpiresAt       DATETIMEOFFSET  NOT NULL,
    RevokedAt       DATETIMEOFFSET  NULL,
    IsActive        AS (CASE WHEN RevokedAt IS NULL AND ExpiresAt > SYSDATETIMEOFFSET() THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END),
    CONSTRAINT PK_Session PRIMARY KEY CLUSTERED (SessionID),
    CONSTRAINT FK_Session_User FOREIGN KEY (UserID) REFERENCES core.Users (UserID)
);
CREATE NONCLUSTERED INDEX IX_Session_User ON auth.Session (UserID) WHERE RevokedAt IS NULL;
CREATE NONCLUSTERED INDEX IX_Session_Expiry ON auth.Session (ExpiresAt) WHERE RevokedAt IS NULL;
GO

-- 4.10 auth.MfaDevice
CREATE TABLE auth.MfaDevice (
    MfaDeviceID     UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    UserID          UNIQUEIDENTIFIER NOT NULL,
    DeviceType      VARCHAR(20)     NOT NULL,   -- 'TOTP','SMS','EMAIL'
    SecretEncrypted NVARCHAR(500)   NULL,
    PhoneNumber     VARCHAR(20)     NULL,
    IsVerified      BIT             NOT NULL DEFAULT 0,
    IsPrimary       BIT             NOT NULL DEFAULT 0,
    CreatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_MfaDevice PRIMARY KEY CLUSTERED (MfaDeviceID),
    CONSTRAINT FK_MfaDevice_User FOREIGN KEY (UserID) REFERENCES core.Users (UserID)
);
GO

-- ============================================================
-- 5. AUDIT / HIPAA COMPLIANCE  (audit schema)
-- ============================================================

-- 5.1  audit.ActivityLog — every user action; HIPAA access tracking
-- Partitioned by CreatedAt (partition scheme defined below)
CREATE TABLE audit.ActivityLog (
    ActivityLogID   BIGINT          NOT NULL IDENTITY(1,1),
    TenantID        UNIQUEIDENTIFIER NOT NULL,
    UserID          UNIQUEIDENTIFIER NULL,
    SessionID       UNIQUEIDENTIFIER NULL,
    EntityType      VARCHAR(60)     NOT NULL,   -- 'Patient','Invoice', etc.
    EntityID        NVARCHAR(100)   NULL,
    Action          VARCHAR(60)     NOT NULL,   -- 'VIEW','CREATE','UPDATE','DELETE','EXPORT'
    Module          VARCHAR(60)     NOT NULL,
    IpAddress       VARCHAR(45)     NULL,
    UserAgent       NVARCHAR(500)   NULL,
    RequestPath     NVARCHAR(500)   NULL,
    OldValueJson    NVARCHAR(MAX)   NULL,
    NewValueJson    NVARCHAR(MAX)   NULL,
    ResultCode      SMALLINT        NOT NULL DEFAULT 200,
    ErrorMessage    NVARCHAR(1000)  NULL,
    DurationMs      INT             NULL,
    CreatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_ActivityLog PRIMARY KEY CLUSTERED (ActivityLogID)
);
-- Composite index for HIPAA audit reports (patient + date range)
CREATE NONCLUSTERED INDEX IX_ActivityLog_Entity
    ON audit.ActivityLog (EntityType, EntityID, CreatedAt DESC);
CREATE NONCLUSTERED INDEX IX_ActivityLog_User
    ON audit.ActivityLog (UserID, CreatedAt DESC);
GO

-- 5.2  audit.ChangeHistory — field-level diffs for temporal records
CREATE TABLE audit.ChangeHistory (
    ChangeHistoryID BIGINT          NOT NULL IDENTITY(1,1),
    TenantID        UNIQUEIDENTIFIER NOT NULL,
    TableName       NVARCHAR(100)   NOT NULL,
    RecordID        NVARCHAR(100)   NOT NULL,
    FieldName       NVARCHAR(100)   NOT NULL,
    OldValue        NVARCHAR(MAX)   NULL,
    NewValue        NVARCHAR(MAX)   NULL,
    ChangedByUserID UNIQUEIDENTIFIER NULL,
    ChangedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    ChangeReason    NVARCHAR(500)   NULL,
    CONSTRAINT PK_ChangeHistory PRIMARY KEY CLUSTERED (ChangeHistoryID)
);
CREATE NONCLUSTERED INDEX IX_ChangeHistory_Record
    ON audit.ChangeHistory (TableName, RecordID, ChangedAt DESC);
GO

-- 5.3  audit.SecurityEvent — login failures, lockouts, suspicious activity
CREATE TABLE audit.SecurityEvent (
    SecurityEventID BIGINT          NOT NULL IDENTITY(1,1),
    TenantID        UNIQUEIDENTIFIER NULL,
    UserID          UNIQUEIDENTIFIER NULL,
    EventType       VARCHAR(60)     NOT NULL,   -- 'LOGIN_FAIL','LOCKOUT','MFA_FAIL'
    Severity        VARCHAR(20)     NOT NULL DEFAULT 'INFO',
    IpAddress       VARCHAR(45)     NULL,
    UserAgent       NVARCHAR(500)   NULL,
    Details         NVARCHAR(MAX)   NULL,
    CreatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_SecurityEvent PRIMARY KEY CLUSTERED (SecurityEventID)
);
CREATE NONCLUSTERED INDEX IX_SecEvent_UserDate
    ON audit.SecurityEvent (UserID, CreatedAt DESC);
GO

-- ============================================================
-- 6. PROVIDER MANAGEMENT  (core schema)
-- ============================================================

CREATE TABLE core.Provider (
    ProviderID      UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantID        UNIQUEIDENTIFIER NOT NULL,
    OrganizationID  UNIQUEIDENTIFIER NULL,
    UserID          UNIQUEIDENTIFIER NULL,   -- linked portal user if any
    Npi             VARCHAR(10)     NULL,
    FirstName       NVARCHAR(100)   NOT NULL,
    LastName        NVARCHAR(100)   NOT NULL,
    Credentials     NVARCHAR(100)   NULL,   -- 'MD','DO','NP','PA'
    Specialty       NVARCHAR(150)   NULL,
    Email           NVARCHAR(200)   NULL,
    Phone           VARCHAR(20)     NULL,
    IsActive        BIT             NOT NULL DEFAULT 1,
    CreatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    DeletedAt       DATETIMEOFFSET  NULL,
    RowVersion      ROWVERSION      NOT NULL,
    CONSTRAINT PK_Provider PRIMARY KEY CLUSTERED (ProviderID),
    CONSTRAINT FK_Provider_Tenant FOREIGN KEY (TenantID) REFERENCES core.Tenant (TenantID),
    CONSTRAINT FK_Provider_User FOREIGN KEY (UserID) REFERENCES core.Users (UserID)
);
CREATE NONCLUSTERED INDEX IX_Provider_Tenant ON core.Provider (TenantID) WHERE DeletedAt IS NULL;
GO

-- ============================================================
-- 7. PATIENT MANAGEMENT  (patient schema)
-- ============================================================

-- 7.1  patient.Patient — temporal table for full history
CREATE TABLE patient.Patient (
    PatientID           UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantID            UNIQUEIDENTIFIER NOT NULL,
    OrganizationID      UNIQUEIDENTIFIER NULL,
    PatientNumber       AS ('P-' + RIGHT('000000' + CAST(PatientSeq AS VARCHAR(10)), 6)) PERSISTED,
    PatientSeq          INT             NOT NULL IDENTITY(100000,1),
    FirstName           NVARCHAR(100)   NOT NULL,
    MiddleName          NVARCHAR(100)   NULL,
    LastName            NVARCHAR(100)   NOT NULL,
    PreferredName       NVARCHAR(100)   NULL,
    DateOfBirth         DATE            NOT NULL,
    GenderCode          VARCHAR(20)     NULL,   -- FK via Lookup
    RaceCode            VARCHAR(20)     NULL,
    EthnicityCode       VARCHAR(20)     NULL,
    PreferredLanguage   VARCHAR(10)     NULL,   -- ISO 639-1
    MaritalStatus       VARCHAR(20)     NULL,
    SSNEncrypted        NVARCHAR(500)   NULL,   -- Always encrypted
    SSNLastFour         CHAR(4)         NULL,
    AddressLine1        NVARCHAR(200)   NULL,
    AddressLine2        NVARCHAR(200)   NULL,
    City                NVARCHAR(100)   NULL,
    StateCode           CHAR(2)         NULL,
    ZipCode             VARCHAR(10)     NULL,
    County              NVARCHAR(100)   NULL,
    Phone               VARCHAR(20)     NULL,
    PhoneMobile         VARCHAR(20)     NULL,
    Email               NVARCHAR(200)   NULL,
    PatientStatus       VARCHAR(30)     NOT NULL DEFAULT 'ACTIVE',
    IsDeceased          BIT             NOT NULL DEFAULT 0,
    DeceasedDate        DATE            NULL,
    ReferralSourceCode  VARCHAR(40)     NULL,
    MarketCode          VARCHAR(40)     NULL,   -- e.g. 'AUSTIN_TX'
    BrightreePatientID  VARCHAR(50)     NULL,   -- external EMR integration
    ExternalPatientID   VARCHAR(100)    NULL,
    Notes               NVARCHAR(MAX)   NULL,
    IsActive            BIT             NOT NULL DEFAULT 1,
    CreatedAt           DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CreatedByUserID     UNIQUEIDENTIFIER NULL,
    UpdatedAt           DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedByUserID     UNIQUEIDENTIFIER NULL,
    RowVersion          ROWVERSION      NOT NULL,
    DeletedAt           DATETIMEOFFSET  NULL,
    -- Temporal table columns for full history
    SysStartTime        DATETIME2       GENERATED ALWAYS AS ROW START NOT NULL,
    SysEndTime          DATETIME2       GENERATED ALWAYS AS ROW END   NOT NULL,
    PERIOD FOR SYSTEM_TIME (SysStartTime, SysEndTime),
    CONSTRAINT PK_Patient PRIMARY KEY CLUSTERED (PatientID),
    CONSTRAINT FK_Patient_Tenant FOREIGN KEY (TenantID) REFERENCES core.Tenant (TenantID),
    CONSTRAINT FK_Patient_Org FOREIGN KEY (OrganizationID) REFERENCES core.Organization (OrganizationID)
) WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = patient.PatientHistory));
GO

CREATE NONCLUSTERED INDEX IX_Patient_TenantStatus
    ON patient.Patient (TenantID, PatientStatus) WHERE DeletedAt IS NULL;
CREATE NONCLUSTERED INDEX IX_Patient_LastName
    ON patient.Patient (TenantID, LastName, FirstName) INCLUDE (DateOfBirth, PatientNumber)
    WHERE DeletedAt IS NULL;
CREATE NONCLUSTERED INDEX IX_Patient_BrightreeID
    ON patient.Patient (BrightreePatientID) WHERE BrightreePatientID IS NOT NULL;
GO

-- 7.2  patient.EmergencyContact
CREATE TABLE patient.EmergencyContact (
    EmergencyContactID  UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    PatientID           UNIQUEIDENTIFIER NOT NULL,
    ContactName         NVARCHAR(200)   NOT NULL,
    Relationship        VARCHAR(40)     NULL,
    Phone               VARCHAR(20)     NULL,
    PhoneMobile         VARCHAR(20)     NULL,
    Email               NVARCHAR(200)   NULL,
    IsPrimary           BIT             NOT NULL DEFAULT 0,
    CONSTRAINT PK_EmergencyContact PRIMARY KEY CLUSTERED (EmergencyContactID),
    CONSTRAINT FK_EmgContact_Patient FOREIGN KEY (PatientID) REFERENCES patient.Patient (PatientID)
);
GO

-- 7.3  patient.InsurancePlan — master plan reference
CREATE TABLE patient.InsurancePlan (
    InsurancePlanID UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantID        UNIQUEIDENTIFIER NOT NULL,
    PayerName       NVARCHAR(200)   NOT NULL,
    PayerCode       VARCHAR(40)     NULL,
    PayerType       VARCHAR(30)     NOT NULL,   -- 'MEDICARE','MEDICAID','COMMERCIAL','SELF_PAY'
    ElectronicPayerID VARCHAR(20)   NULL,       -- 837/835 payer ID
    Phone           VARCHAR(20)     NULL,
    WebPortalUrl    NVARCHAR(300)   NULL,
    IsActive        BIT             NOT NULL DEFAULT 1,
    CONSTRAINT PK_InsurancePlan PRIMARY KEY CLUSTERED (InsurancePlanID),
    CONSTRAINT FK_InsurancePlan_Tenant FOREIGN KEY (TenantID) REFERENCES core.Tenant (TenantID)
);
GO

-- 7.4  patient.PatientInsurance — patient's coverage instances
CREATE TABLE patient.PatientInsurance (
    PatientInsuranceID  UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    PatientID           UNIQUEIDENTIFIER NOT NULL,
    InsurancePlanID     UNIQUEIDENTIFIER NOT NULL,
    Priority            TINYINT         NOT NULL,  -- 1=Primary, 2=Secondary, 3=Tertiary
    MemberID            NVARCHAR(100)   NOT NULL,
    GroupNumber         NVARCHAR(100)   NULL,
    PolicyHolder        NVARCHAR(200)   NULL,
    PolicyHolderDOB     DATE            NULL,
    RelationToPatient   VARCHAR(30)     NULL,
    EffectiveDate       DATE            NULL,
    TerminationDate     DATE            NULL,
    EligibilityStatus   VARCHAR(30)     NULL,
    LastEligibilityCheck DATETIMEOFFSET NULL,
    CopayAmount         DECIMAL(10,2)   NULL,
    DeductibleAmount    DECIMAL(10,2)   NULL,
    IsActive            BIT             NOT NULL DEFAULT 1,
    CreatedAt           DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_PatientInsurance PRIMARY KEY CLUSTERED (PatientInsuranceID),
    CONSTRAINT FK_PatIns_Patient FOREIGN KEY (PatientID) REFERENCES patient.Patient (PatientID),
    CONSTRAINT FK_PatIns_Plan FOREIGN KEY (InsurancePlanID) REFERENCES patient.InsurancePlan (InsurancePlanID),
    CONSTRAINT UQ_PatIns_Priority UNIQUE (PatientID, Priority, IsActive)
);
GO

-- 7.5  patient.Allergy
CREATE TABLE patient.Allergy (
    AllergyID       UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    PatientID       UNIQUEIDENTIFIER NOT NULL,
    AllergenName    NVARCHAR(200)   NOT NULL,
    AllergenType    VARCHAR(30)     NULL,   -- 'DRUG','FOOD','ENVIRONMENT'
    Reaction        NVARCHAR(300)   NULL,
    Severity        VARCHAR(20)     NULL,   -- 'MILD','MODERATE','SEVERE'
    OnsetDate       DATE            NULL,
    IsActive        BIT             NOT NULL DEFAULT 1,
    CreatedByUserID UNIQUEIDENTIFIER NULL,
    CreatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_Allergy PRIMARY KEY CLUSTERED (AllergyID),
    CONSTRAINT FK_Allergy_Patient FOREIGN KEY (PatientID) REFERENCES patient.Patient (PatientID)
);
GO

-- 7.6  patient.Medication
CREATE TABLE patient.Medication (
    MedicationID    UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    PatientID       UNIQUEIDENTIFIER NOT NULL,
    DrugName        NVARCHAR(200)   NOT NULL,
    GenericName     NVARCHAR(200)   NULL,
    DoseStrength    NVARCHAR(80)    NULL,
    RouteCode       VARCHAR(20)     NULL,
    Frequency       NVARCHAR(80)    NULL,
    Prescriber      NVARCHAR(200)   NULL,
    StartDate       DATE            NULL,
    EndDate         DATE            NULL,
    IsActive        BIT             NOT NULL DEFAULT 1,
    Notes           NVARCHAR(500)   NULL,
    CreatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_Medication PRIMARY KEY CLUSTERED (MedicationID),
    CONSTRAINT FK_Medication_Patient FOREIGN KEY (PatientID) REFERENCES patient.Patient (PatientID)
);
GO

-- 7.7  patient.Diagnosis
CREATE TABLE patient.Diagnosis (
    DiagnosisID     UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    PatientID       UNIQUEIDENTIFIER NOT NULL,
    IcdCode         VARCHAR(15)     NOT NULL,   -- ICD-10
    IcdDescription NVARCHAR(300)   NULL,
    DiagnosisType   VARCHAR(30)     NULL,       -- 'PRIMARY','SECONDARY','COMORBIDITY'
    DiagnosisDate   DATE            NULL,
    DiagnosedBy     NVARCHAR(200)   NULL,
    IsActive        BIT             NOT NULL DEFAULT 1,
    CreatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_Diagnosis PRIMARY KEY CLUSTERED (DiagnosisID),
    CONSTRAINT FK_Diagnosis_Patient FOREIGN KEY (PatientID) REFERENCES patient.Patient (PatientID)
);
CREATE NONCLUSTERED INDEX IX_Diagnosis_Patient ON patient.Diagnosis (PatientID) WHERE IsActive = 1;
GO

-- 7.8  patient.Note — clinical + operational notes
CREATE TABLE patient.Note (
    NoteID          UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    PatientID       UNIQUEIDENTIFIER NOT NULL,
    TenantID        UNIQUEIDENTIFIER NOT NULL,
    NoteType        VARCHAR(40)     NOT NULL,   -- 'CLINICAL','INTAKE','BILLING','GENERAL'
    Subject         NVARCHAR(300)   NULL,
    NoteText        NVARCHAR(MAX)   NOT NULL,
    IsPrivate       BIT             NOT NULL DEFAULT 0,
    AuthoredByUserID UNIQUEIDENTIFIER NOT NULL,
    AuthoredAt      DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    DeletedAt       DATETIMEOFFSET  NULL,
    CONSTRAINT PK_Note PRIMARY KEY CLUSTERED (NoteID),
    CONSTRAINT FK_Note_Patient FOREIGN KEY (PatientID) REFERENCES patient.Patient (PatientID)
);
CREATE NONCLUSTERED INDEX IX_Note_Patient ON patient.Note (PatientID, AuthoredAt DESC)
    WHERE DeletedAt IS NULL;
GO

-- 7.9  patient.Document — files/attachments
CREATE TABLE patient.Document (
    DocumentID      UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantID        UNIQUEIDENTIFIER NOT NULL,
    PatientID       UNIQUEIDENTIFIER NULL,
    RelatedEntityType VARCHAR(60)   NULL,       -- 'Audit','Claim','Referral'
    RelatedEntityID NVARCHAR(100)   NULL,
    DocumentType    VARCHAR(60)     NOT NULL,   -- 'SLEEP_STUDY','RX','CMN','EOB','CONSENT'
    FileName        NVARCHAR(300)   NOT NULL,
    ContentType     VARCHAR(100)    NOT NULL,
    FileSizeBytes   BIGINT          NOT NULL,
    StoragePath     NVARCHAR(500)   NOT NULL,   -- Azure Blob / S3 path
    BlobContainerName NVARCHAR(200) NULL,
    Checksum        NVARCHAR(100)   NULL,
    IsEncrypted     BIT             NOT NULL DEFAULT 1,
    IsActive        BIT             NOT NULL DEFAULT 1,
    UploadedByUserID UNIQUEIDENTIFIER NULL,
    UploadedAt      DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    DeletedAt       DATETIMEOFFSET  NULL,
    CONSTRAINT PK_Document PRIMARY KEY CLUSTERED (DocumentID),
    CONSTRAINT FK_Document_Patient FOREIGN KEY (PatientID) REFERENCES patient.Patient (PatientID)
);
CREATE NONCLUSTERED INDEX IX_Document_Patient ON patient.Document (PatientID, DocumentType)
    WHERE DeletedAt IS NULL;
CREATE NONCLUSTERED INDEX IX_Document_Entity
    ON patient.Document (RelatedEntityType, RelatedEntityID) WHERE DeletedAt IS NULL;
GO

-- ============================================================
-- 8. CLINICAL / ADHERENCE  (clinical schema)
-- ============================================================

-- 8.1  clinical.Order — DME equipment orders
CREATE TABLE clinical.Orders (
    OrderID         UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantID        UNIQUEIDENTIFIER NOT NULL,
    PatientID       UNIQUEIDENTIFIER NOT NULL,
    ProviderID      UNIQUEIDENTIFIER NULL,
    OrganizationID  UNIQUEIDENTIFIER NULL,
    OrderNumber     NVARCHAR(40)     NULL,
    OrderType       VARCHAR(40)     NOT NULL,   -- 'CPAP','BIPAP','OXYGEN','NEBULIZER'
    HcpcsCode       VARCHAR(10)     NULL,
    IcdCodes        NVARCHAR(200)   NULL,       -- comma-separated ICD-10 codes
    OrderDate       DATE            NOT NULL,
    SetupDate       DATE            NULL,
    DischargeDate   DATE            NULL,
    OrderStatus     VARCHAR(30)     NOT NULL DEFAULT 'PENDING',
    Quantity        SMALLINT        NOT NULL DEFAULT 1,
    ResupplyFreq    VARCHAR(30)     NULL,       -- '1MONTH','3MONTH','6MONTH'
    Notes           NVARCHAR(MAX)   NULL,
    ExternalOrderID VARCHAR(100)    NULL,       -- Brightree order ID
    CreatedByUserID UNIQUEIDENTIFIER NULL,
    CreatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    DeletedAt       DATETIMEOFFSET  NULL,
    RowVersion      ROWVERSION      NOT NULL,
    CONSTRAINT PK_Order PRIMARY KEY CLUSTERED (OrderID),
    CONSTRAINT FK_Order_Patient FOREIGN KEY (PatientID) REFERENCES patient.Patient (PatientID),
    CONSTRAINT FK_Order_Provider FOREIGN KEY (ProviderID) REFERENCES core.Provider (ProviderID)
);
CREATE NONCLUSTERED INDEX IX_Order_Patient ON clinical.Orders (PatientID, OrderStatus)
    WHERE DeletedAt IS NULL;
GO

-- 8.2  clinical.AdherenceRecord — daily compliance uploads from device
CREATE TABLE clinical.AdherenceRecord (
    AdherenceRecordID   UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantID            UNIQUEIDENTIFIER NOT NULL,
    PatientID           UNIQUEIDENTIFIER NOT NULL,
    OrderID             UNIQUEIDENTIFIER NOT NULL,
    RecordDate          DATE            NOT NULL,
    UsageHours          DECIMAL(5,2)    NULL,       -- hours/day of device use
    AhiScore            DECIMAL(5,1)    NULL,       -- apnea/hypopnea index
    LeakRate            DECIMAL(6,2)    NULL,
    ComplianceFlag      BIT             NOT NULL DEFAULT 0,  -- ≥4 hrs on ≥70% of days
    DeviceSerialNumber  NVARCHAR(100)   NULL,
    DataSource          VARCHAR(30)     NULL,       -- 'RESMED','PHILIPS','MANUAL'
    UploadedAt          DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_AdherenceRecord PRIMARY KEY CLUSTERED (AdherenceRecordID),
    CONSTRAINT UQ_Adherence_PatientDate UNIQUE (PatientID, OrderID, RecordDate),
    CONSTRAINT FK_Adherence_Patient FOREIGN KEY (PatientID) REFERENCES patient.Patient (PatientID),
    CONSTRAINT FK_Adherence_Order FOREIGN KEY (OrderID) REFERENCES clinical.Orders (OrderID)
);
CREATE NONCLUSTERED INDEX IX_Adherence_PatientDate
    ON clinical.AdherenceRecord (PatientID, RecordDate DESC);
GO

-- 8.3  clinical.AdherenceScore — 30/60/90-day computed scores
CREATE TABLE clinical.AdherenceScore (
    AdherenceScoreID    UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    PatientID           UNIQUEIDENTIFIER NOT NULL,
    OrderID             UNIQUEIDENTIFIER NOT NULL,
    PeriodDays          TINYINT         NOT NULL,   -- 30, 60, 90
    PeriodEndDate       DATE            NOT NULL,
    AvgUsageHours       DECIMAL(5,2)    NULL,
    CompliantDays       INT             NULL,
    TotalDays           INT             NULL,
    CompliancePct       DECIMAL(5,2)    NULL,
    AdherenceStatusCode VARCHAR(20)     NULL,   -- 'COMPLIANT','AT_RISK','NON_COMPLIANT'
    ComputedAt          DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_AdherenceScore PRIMARY KEY CLUSTERED (AdherenceScoreID),
    CONSTRAINT FK_AdherenceScore_Patient FOREIGN KEY (PatientID) REFERENCES patient.Patient (PatientID)
);
GO

-- 8.4  clinical.OutreachLog — contact attempts for non-compliant patients
CREATE TABLE clinical.OutreachLog (
    OutreachLogID   UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantID        UNIQUEIDENTIFIER NOT NULL,
    PatientID       UNIQUEIDENTIFIER NOT NULL,
    OrderID         UNIQUEIDENTIFIER NULL,
    OutreachType    VARCHAR(30)     NOT NULL,   -- 'PHONE','SMS','EMAIL','MAIL'
    Direction       VARCHAR(10)     NOT NULL DEFAULT 'OUTBOUND',
    OutcomeCode     VARCHAR(40)     NULL,       -- 'REACHED','VOICEMAIL','NO_ANSWER'
    Notes           NVARCHAR(1000)  NULL,
    ConductedByUserID UNIQUEIDENTIFIER NULL,
    OutreachAt      DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_OutreachLog PRIMARY KEY CLUSTERED (OutreachLogID),
    CONSTRAINT FK_Outreach_Patient FOREIGN KEY (PatientID) REFERENCES patient.Patient (PatientID)
);
GO

-- 8.5  clinical.CarePlan
CREATE TABLE clinical.CarePlan (
    CarePlanID      UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    PatientID       UNIQUEIDENTIFIER NOT NULL,
    TenantID        UNIQUEIDENTIFIER NOT NULL,
    PlanTitle       NVARCHAR(200)   NOT NULL,
    Goals           NVARCHAR(MAX)   NULL,
    StartDate       DATE            NULL,
    EndDate         DATE            NULL,
    PlanStatus      VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE',
    CreatedByUserID UNIQUEIDENTIFIER NULL,
    CreatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_CarePlan PRIMARY KEY CLUSTERED (CarePlanID),
    CONSTRAINT FK_CarePlan_Patient FOREIGN KEY (PatientID) REFERENCES patient.Patient (PatientID)
);
GO

-- ============================================================
-- 9. INTAKE / REFERRAL  (intake schema)
-- ============================================================

-- 9.1  intake.Referral — new referrals from fax / Brightree import
CREATE TABLE intake.Referral (
    ReferralID      UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantID        UNIQUEIDENTIFIER NOT NULL,
    OrganizationID  UNIQUEIDENTIFIER NULL,
    ReferralNumber  NVARCHAR(30)     NULL,    -- FAX-10347, auto-generated
    SourceType      VARCHAR(30)     NOT NULL, -- 'FAX','BRIGHTREE','MANUAL','EDI'
    ReferralStatus  VARCHAR(30)     NOT NULL DEFAULT 'NEW',
    Priority        VARCHAR(20)     NOT NULL DEFAULT 'NORMAL',
    PatientID       UNIQUEIDENTIFIER NULL,    -- linked after search/match
    ProviderID      UNIQUEIDENTIFIER NULL,
    -- Patient info at intake time (before patient record created)
    IntakeFirstName NVARCHAR(100)   NULL,
    IntakeLastName  NVARCHAR(100)   NULL,
    IntakeDOB       DATE            NULL,
    IntakePhone     VARCHAR(20)     NULL,
    IntakeInsuranceID NVARCHAR(100) NULL,
    IntakeInsuranceName NVARCHAR(200) NULL,
    OrderType       VARCHAR(60)     NULL,
    DiagnosisCodes  NVARCHAR(200)   NULL,
    PrescriberName  NVARCHAR(200)   NULL,
    PrescriberNpi   VARCHAR(10)     NULL,
    ClinicalNotes   NVARCHAR(MAX)   NULL,
    FaxNumber       VARCHAR(20)     NULL,
    ReceivedAt      DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    AssignedToUserID UNIQUEIDENTIFIER NULL,
    DueDate         DATETIMEOFFSET  NULL,
    ClosedAt        DATETIMEOFFSET  NULL,
    ClosedByUserID  UNIQUEIDENTIFIER NULL,
    ClosureReason   NVARCHAR(300)   NULL,
    CreatedByUserID UNIQUEIDENTIFIER NULL,
    CreatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    RowVersion      ROWVERSION      NOT NULL,
    DeletedAt       DATETIMEOFFSET  NULL,
    CONSTRAINT PK_Referral PRIMARY KEY CLUSTERED (ReferralID),
    CONSTRAINT FK_Referral_Tenant FOREIGN KEY (TenantID) REFERENCES core.Tenant (TenantID),
    CONSTRAINT FK_Referral_Patient FOREIGN KEY (PatientID) REFERENCES patient.Patient (PatientID)
);
CREATE NONCLUSTERED INDEX IX_Referral_Status ON intake.Referral (TenantID, ReferralStatus, ReceivedAt DESC)
    WHERE DeletedAt IS NULL;
CREATE NONCLUSTERED INDEX IX_Referral_Assigned ON intake.Referral (AssignedToUserID, ReferralStatus)
    WHERE DeletedAt IS NULL AND ClosedAt IS NULL;
GO

-- 9.2  intake.ReferralStatusHistory
CREATE TABLE intake.ReferralStatusHistory (
    StatusHistoryID UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    ReferralID      UNIQUEIDENTIFIER NOT NULL,
    FromStatus      VARCHAR(30)     NULL,
    ToStatus        VARCHAR(30)     NOT NULL,
    ChangedByUserID UNIQUEIDENTIFIER NULL,
    Notes           NVARCHAR(500)   NULL,
    ChangedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_ReferralStatusHistory PRIMARY KEY CLUSTERED (StatusHistoryID),
    CONSTRAINT FK_RefStatus_Referral FOREIGN KEY (ReferralID) REFERENCES intake.Referral (ReferralID)
);
GO

-- 9.3  intake.FormTemplate — dynamic questionnaire engine
CREATE TABLE intake.FormTemplate (
    FormTemplateID  UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantID        UNIQUEIDENTIFIER NOT NULL,
    TemplateCode    VARCHAR(60)     NOT NULL,
    TemplateName    NVARCHAR(200)   NOT NULL,
    FormCategory    VARCHAR(40)     NOT NULL,  -- 'INTAKE','CONSENT','QUESTIONNAIRE'
    SchemaJson      NVARCHAR(MAX)   NOT NULL,  -- JSON Schema for field definitions
    VersionNumber   SMALLINT        NOT NULL DEFAULT 1,
    IsActive        BIT             NOT NULL DEFAULT 1,
    CreatedByUserID UNIQUEIDENTIFIER NULL,
    CreatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_FormTemplate PRIMARY KEY CLUSTERED (FormTemplateID),
    CONSTRAINT UQ_FormTemplate UNIQUE (TenantID, TemplateCode, VersionNumber)
);
GO

-- 9.4  intake.FormSubmission — completed forms
CREATE TABLE intake.FormSubmission (
    FormSubmissionID UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantID         UNIQUEIDENTIFIER NOT NULL,
    FormTemplateID   UNIQUEIDENTIFIER NOT NULL,
    PatientID        UNIQUEIDENTIFIER NULL,
    ReferralID       UNIQUEIDENTIFIER NULL,
    SubmissionStatus VARCHAR(30)     NOT NULL DEFAULT 'DRAFT',
    AnswersJson      NVARCHAR(MAX)   NULL,
    SignatureData    NVARCHAR(MAX)   NULL,   -- base64 sig or DocuSign envelope
    SignedByName     NVARCHAR(200)   NULL,
    SignedAt         DATETIMEOFFSET  NULL,
    SubmittedByUserID UNIQUEIDENTIFIER NULL,
    SubmittedAt      DATETIMEOFFSET  NULL,
    CreatedAt        DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_FormSubmission PRIMARY KEY CLUSTERED (FormSubmissionID),
    CONSTRAINT FK_FormSub_Template FOREIGN KEY (FormTemplateID) REFERENCES intake.FormTemplate (FormTemplateID),
    CONSTRAINT FK_FormSub_Patient FOREIGN KEY (PatientID) REFERENCES patient.Patient (PatientID)
);
GO

-- ============================================================
-- 10. BILLING / CLAIMS  (billing schema)
-- ============================================================

-- 10.1  billing.Invoice
CREATE TABLE billing.Invoice (
    InvoiceID       UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantID        UNIQUEIDENTIFIER NOT NULL,
    PatientID       UNIQUEIDENTIFIER NOT NULL,
    OrganizationID  UNIQUEIDENTIFIER NULL,
    InvoiceNumber   NVARCHAR(30)    NOT NULL,   -- INV-87-002194
    InvoiceDate     DATE            NOT NULL,
    DueDate         DATE            NULL,
    ServiceStartDate DATE           NULL,
    ServiceEndDate  DATE            NULL,
    InvoiceType     VARCHAR(40)     NOT NULL,   -- 'INITIAL_SETUP','RESUPPLY','REPLACEMENT'
    ProductDescription NVARCHAR(300) NULL,
    HcpcsCode       VARCHAR(10)     NULL,
    InsurancePlanID UNIQUEIDENTIFIER NULL,
    InvoiceAmount   DECIMAL(12,2)   NOT NULL,
    PatientResponsibility DECIMAL(12,2) NULL,
    AdjustmentAmount DECIMAL(12,2)  NULL DEFAULT 0,
    PaidAmount      DECIMAL(12,2)   NULL DEFAULT 0,
    BalanceDue      AS (InvoiceAmount - ISNULL(PaidAmount,0) - ISNULL(AdjustmentAmount,0)) PERSISTED,
    InvoiceStatus   VARCHAR(30)     NOT NULL DEFAULT 'PENDING',
    AssignedToUserID UNIQUEIDENTIFIER NULL,
    ExternalInvoiceID VARCHAR(100)  NULL,
    Notes           NVARCHAR(MAX)   NULL,
    CreatedByUserID UNIQUEIDENTIFIER NULL,
    CreatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    RowVersion      ROWVERSION      NOT NULL,
    DeletedAt       DATETIMEOFFSET  NULL,
    CONSTRAINT PK_Invoice PRIMARY KEY CLUSTERED (InvoiceID),
    CONSTRAINT UQ_Invoice_Number UNIQUE (TenantID, InvoiceNumber),
    CONSTRAINT FK_Invoice_Patient FOREIGN KEY (PatientID) REFERENCES patient.Patient (PatientID),
    CONSTRAINT FK_Invoice_InsurancePlan FOREIGN KEY (InsurancePlanID) REFERENCES patient.InsurancePlan (InsurancePlanID)
);
CREATE NONCLUSTERED INDEX IX_Invoice_Patient ON billing.Invoice (PatientID, InvoiceStatus)
    WHERE DeletedAt IS NULL;
CREATE NONCLUSTERED INDEX IX_Invoice_Status ON billing.Invoice (TenantID, InvoiceStatus, InvoiceDate DESC)
    WHERE DeletedAt IS NULL;
-- Filtered index for pending refunds dashboard widget
CREATE NONCLUSTERED INDEX IX_Invoice_PendingRefunds
    ON billing.Invoice (TenantID, BalanceDue, InvoiceDate)
    WHERE InvoiceStatus = 'UNDER_REVIEW' AND DeletedAt IS NULL;
GO

-- 10.2  billing.InvoiceStatusHistory
CREATE TABLE billing.InvoiceStatusHistory (
    StatusHistoryID UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    InvoiceID       UNIQUEIDENTIFIER NOT NULL,
    FromStatus      VARCHAR(30)     NULL,
    ToStatus        VARCHAR(30)     NOT NULL,
    Reason          NVARCHAR(300)   NULL,
    ChangedByUserID UNIQUEIDENTIFIER NULL,
    ChangedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_InvStatusHistory PRIMARY KEY CLUSTERED (StatusHistoryID),
    CONSTRAINT FK_InvStatus_Invoice FOREIGN KEY (InvoiceID) REFERENCES billing.Invoice (InvoiceID)
);
GO

-- 10.3  billing.Claim — 837 professional/institutional claims
CREATE TABLE billing.Claim (
    ClaimID         UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantID        UNIQUEIDENTIFIER NOT NULL,
    InvoiceID       UNIQUEIDENTIFIER NOT NULL,
    PatientID       UNIQUEIDENTIFIER NOT NULL,
    PatientInsuranceID UNIQUEIDENTIFIER NULL,
    ClaimNumber     NVARCHAR(30)    NOT NULL,
    ClaimType       VARCHAR(20)     NOT NULL DEFAULT 'PROFESSIONAL',  -- 'PROFESSIONAL','INSTITUTIONAL'
    ClaimStatus     VARCHAR(30)     NOT NULL DEFAULT 'DRAFT',
    SubmittedAt     DATETIMEOFFSET  NULL,
    PayerClaimNumber NVARCHAR(60)   NULL,
    ServiceDate     DATE            NULL,
    BilledAmount    DECIMAL(12,2)   NOT NULL,
    AllowedAmount   DECIMAL(12,2)   NULL,
    PaidAmount      DECIMAL(12,2)   NULL,
    DenialCode      VARCHAR(20)     NULL,
    DenialReason    NVARCHAR(500)   NULL,
    AdjudicatedAt   DATETIMEOFFSET  NULL,
    PriorAuthNumber NVARCHAR(60)    NULL,
    BillingNotes    NVARCHAR(MAX)   NULL,
    CreatedByUserID UNIQUEIDENTIFIER NULL,
    CreatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    RowVersion      ROWVERSION      NOT NULL,
    CONSTRAINT PK_Claim PRIMARY KEY CLUSTERED (ClaimID),
    CONSTRAINT UQ_Claim_Number UNIQUE (TenantID, ClaimNumber),
    CONSTRAINT FK_Claim_Invoice FOREIGN KEY (InvoiceID) REFERENCES billing.Invoice (InvoiceID),
    CONSTRAINT FK_Claim_Patient FOREIGN KEY (PatientID) REFERENCES patient.Patient (PatientID)
);
CREATE NONCLUSTERED INDEX IX_Claim_PatientStatus ON billing.Claim (PatientID, ClaimStatus);
GO

-- 10.4  billing.Refund
CREATE TABLE billing.Refund (
    RefundID        UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantID        UNIQUEIDENTIFIER NOT NULL,
    InvoiceID       UNIQUEIDENTIFIER NOT NULL,
    PatientID       UNIQUEIDENTIFIER NOT NULL,
    RefundAmount    DECIMAL(12,2)   NOT NULL,
    RefundReason    NVARCHAR(500)   NULL,
    RefundStatus    VARCHAR(30)     NOT NULL DEFAULT 'PENDING',  -- 'PENDING','APPROVED','REJECTED','PROCESSED'
    RequestedByUserID UNIQUEIDENTIFIER NULL,
    RequestedAt     DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    ReviewedByUserID UNIQUEIDENTIFIER NULL,
    ReviewedAt      DATETIMEOFFSET  NULL,
    ReviewNotes     NVARCHAR(500)   NULL,
    ProcessedAt     DATETIMEOFFSET  NULL,
    CONSTRAINT PK_Refund PRIMARY KEY CLUSTERED (RefundID),
    CONSTRAINT FK_Refund_Invoice FOREIGN KEY (InvoiceID) REFERENCES billing.Invoice (InvoiceID),
    CONSTRAINT FK_Refund_Patient FOREIGN KEY (PatientID) REFERENCES patient.Patient (PatientID)
);
CREATE NONCLUSTERED INDEX IX_Refund_Status ON billing.Refund (TenantID, RefundStatus)
    WHERE RefundStatus IN ('PENDING','APPROVED');
GO

-- 10.5  billing.Payment
CREATE TABLE billing.Payment (
    PaymentID       UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantID        UNIQUEIDENTIFIER NOT NULL,
    PatientID       UNIQUEIDENTIFIER NOT NULL,
    InvoiceID       UNIQUEIDENTIFIER NULL,
    PaymentMethod   VARCHAR(30)     NOT NULL,   -- 'INSURANCE_ERA','PATIENT_CC','CHECK','EFT'
    PaymentAmount   DECIMAL(12,2)   NOT NULL,
    PaymentDate     DATE            NOT NULL,
    CheckNumber     NVARCHAR(50)    NULL,
    EraCheckNumber  NVARCHAR(50)    NULL,
    RemittanceInfoJson NVARCHAR(MAX) NULL,
    ProcessedByUserID UNIQUEIDENTIFIER NULL,
    CreatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_Payment PRIMARY KEY CLUSTERED (PaymentID),
    CONSTRAINT FK_Payment_Invoice FOREIGN KEY (InvoiceID) REFERENCES billing.Invoice (InvoiceID),
    CONSTRAINT FK_Payment_Patient FOREIGN KEY (PatientID) REFERENCES patient.Patient (PatientID)
);
GO

-- 10.6  billing.PriorAuthorization
CREATE TABLE billing.PriorAuthorization (
    PriorAuthID     UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantID        UNIQUEIDENTIFIER NOT NULL,
    PatientID       UNIQUEIDENTIFIER NOT NULL,
    InsurancePlanID UNIQUEIDENTIFIER NOT NULL,
    OrderID         UNIQUEIDENTIFIER NULL,
    AuthNumber      NVARCHAR(60)    NULL,
    HcpcsCode       VARCHAR(10)     NULL,
    AuthStatus      VARCHAR(30)     NOT NULL DEFAULT 'PENDING',
    RequestedAt     DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    ApprovedAt      DATETIMEOFFSET  NULL,
    ExpiresAt       DATETIMEOFFSET  NULL,
    DenialReason    NVARCHAR(500)   NULL,
    UnitsApproved   SMALLINT        NULL,
    Notes           NVARCHAR(MAX)   NULL,
    CONSTRAINT PK_PriorAuth PRIMARY KEY CLUSTERED (PriorAuthID),
    CONSTRAINT FK_PriorAuth_Patient FOREIGN KEY (PatientID) REFERENCES patient.Patient (PatientID),
    CONSTRAINT FK_PriorAuth_Plan FOREIGN KEY (InsurancePlanID) REFERENCES patient.InsurancePlan (InsurancePlanID)
);
GO

-- ============================================================
-- 11. AUDITSHARE MODULE  (audit schema)
-- ============================================================

-- 11.1  audit.AuditCase — the 4-step audit workflow
CREATE TABLE audit.AuditCase (
    AuditCaseID     UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantID        UNIQUEIDENTIFIER NOT NULL,
    CaseNumber      NVARCHAR(20)    NOT NULL,   -- AUD-2041
    PatientID       UNIQUEIDENTIFIER NOT NULL,
    InvoiceID       UNIQUEIDENTIFIER NOT NULL,
    AuditType       VARCHAR(30)     NOT NULL,   -- 'PRE_PAYMENT','POST_PAYMENT','RANDOM'
    PayerName       NVARCHAR(200)   NULL,
    PayerRequestDate DATE           NULL,
    ResponseDeadline DATE           NOT NULL,
    AuditStatus     VARCHAR(30)     NOT NULL DEFAULT 'OPEN',  -- 'OPEN','SUBMITTED','AT_RISK','CLOSED'
    Outcome         VARCHAR(40)     NULL,   -- 'DOCUMENTATION_SENT','APPEALED','CLOSED_FAVORABLE'
    OutcomeNotes    NVARCHAR(MAX)   NULL,
    PayerNotes      NVARCHAR(MAX)   NULL,
    SubmittedAt     DATETIMEOFFSET  NULL,
    SubmittedByUserID UNIQUEIDENTIFIER NULL,
    AssignedToUserID UNIQUEIDENTIFIER NULL,
    IsFlagged       BIT             NOT NULL DEFAULT 0,
    FlaggedByUserID UNIQUEIDENTIFIER NULL,
    FlagReason      NVARCHAR(300)   NULL,
    CreatedByUserID UNIQUEIDENTIFIER NULL,
    CreatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    RowVersion      ROWVERSION      NOT NULL,
    DeletedAt       DATETIMEOFFSET  NULL,
    CONSTRAINT PK_AuditCase PRIMARY KEY CLUSTERED (AuditCaseID),
    CONSTRAINT UQ_AuditCase_Number UNIQUE (TenantID, CaseNumber),
    CONSTRAINT FK_AuditCase_Patient FOREIGN KEY (PatientID) REFERENCES patient.Patient (PatientID),
    CONSTRAINT FK_AuditCase_Invoice FOREIGN KEY (InvoiceID) REFERENCES billing.Invoice (InvoiceID)
);
CREATE NONCLUSTERED INDEX IX_AuditCase_Status ON audit.AuditCase (TenantID, AuditStatus, ResponseDeadline)
    WHERE DeletedAt IS NULL;
-- Filtered index for overdue audits dashboard
CREATE NONCLUSTERED INDEX IX_AuditCase_Overdue
    ON audit.AuditCase (TenantID, ResponseDeadline)
    WHERE AuditStatus = 'OPEN' AND DeletedAt IS NULL;
GO

-- 11.2  audit.AuditCaseDocument — files attached in step 3
CREATE TABLE audit.AuditCaseDocument (
    AuditCaseDocID  UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    AuditCaseID     UNIQUEIDENTIFIER NOT NULL,
    DocumentID      UNIQUEIDENTIFIER NOT NULL,
    AddedByUserID   UNIQUEIDENTIFIER NULL,
    AddedAt         DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    IsLocked        BIT             NOT NULL DEFAULT 0,  -- locked after submission
    CONSTRAINT PK_AuditCaseDoc PRIMARY KEY CLUSTERED (AuditCaseDocID),
    CONSTRAINT FK_AuditCaseDoc_Case FOREIGN KEY (AuditCaseID) REFERENCES audit.AuditCase (AuditCaseID),
    CONSTRAINT FK_AuditCaseDoc_Document FOREIGN KEY (DocumentID) REFERENCES patient.Document (DocumentID)
);
GO

-- 11.3  audit.AuditCaseStatusHistory
CREATE TABLE audit.AuditCaseStatusHistory (
    StatusHistoryID UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    AuditCaseID     UNIQUEIDENTIFIER NOT NULL,
    FromStatus      VARCHAR(30)     NULL,
    ToStatus        VARCHAR(30)     NOT NULL,
    ChangedByUserID UNIQUEIDENTIFIER NULL,
    Notes           NVARCHAR(500)   NULL,
    ChangedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_AuditStatusHist PRIMARY KEY CLUSTERED (StatusHistoryID),
    CONSTRAINT FK_AuditStatusHist_Case FOREIGN KEY (AuditCaseID) REFERENCES audit.AuditCase (AuditCaseID)
);
GO

-- ============================================================
-- 12. NOTIFICATIONS + INBOX  (notify schema)
-- ============================================================

-- 12.1  notify.NotificationTemplate
CREATE TABLE notify.NotificationTemplate (
    TemplateID      INT             NOT NULL IDENTITY(1,1),
    TenantID        UNIQUEIDENTIFIER NULL,
    TemplateCode    VARCHAR(80)     NOT NULL,
    Channel         VARCHAR(20)     NOT NULL,   -- 'EMAIL','SMS','IN_APP'
    Subject         NVARCHAR(300)   NULL,
    BodyTemplate    NVARCHAR(MAX)   NOT NULL,   -- Handlebars / Razor template text
    IsActive        BIT             NOT NULL DEFAULT 1,
    CONSTRAINT PK_NotifyTemplate PRIMARY KEY CLUSTERED (TemplateID),
    CONSTRAINT UQ_NotifyTemplate UNIQUE (TenantID, TemplateCode, Channel)
);
GO

-- 12.2  notify.Notification — in-app inbox items
CREATE TABLE notify.Notification (
    NotificationID  UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantID        UNIQUEIDENTIFIER NOT NULL,
    RecipientUserID UNIQUEIDENTIFIER NOT NULL,
    SenderUserID    UNIQUEIDENTIFIER NULL,
    NotificationType VARCHAR(60)    NOT NULL,   -- 'REFERRAL_NEW','AUDIT_DUE','REFUND_APPROVED'
    Title           NVARCHAR(300)   NOT NULL,
    Message         NVARCHAR(MAX)   NOT NULL,
    Module          VARCHAR(60)     NULL,
    RelatedEntityType VARCHAR(60)   NULL,
    RelatedEntityID NVARCHAR(100)   NULL,
    ActionUrl       NVARCHAR(500)   NULL,
    Priority        VARCHAR(20)     NOT NULL DEFAULT 'NORMAL',
    IsRead          BIT             NOT NULL DEFAULT 0,
    ReadAt          DATETIMEOFFSET  NULL,
    IsDismissed     BIT             NOT NULL DEFAULT 0,
    DismissedAt     DATETIMEOFFSET  NULL,
    CreatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_Notification PRIMARY KEY CLUSTERED (NotificationID),
    CONSTRAINT FK_Notification_Recipient FOREIGN KEY (RecipientUserID) REFERENCES core.Users (UserID)
);
-- Heavy-read index for inbox pane; filtered to unread/unarchived
CREATE NONCLUSTERED INDEX IX_Notification_Inbox
    ON notify.Notification (RecipientUserID, CreatedAt DESC)
    INCLUDE (NotificationType, Title, IsRead, Module)
    WHERE IsDismissed = 0;
GO

-- 12.3  notify.EmailQueue — outbound email delivery queue
CREATE TABLE notify.EmailQueue (
    EmailQueueID    UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantID        UNIQUEIDENTIFIER NOT NULL,
    ToAddress       NVARCHAR(300)   NOT NULL,
    CcAddresses     NVARCHAR(MAX)   NULL,
    Subject         NVARCHAR(500)   NOT NULL,
    HtmlBody        NVARCHAR(MAX)   NOT NULL,
    TextBody        NVARCHAR(MAX)   NULL,
    Status          VARCHAR(20)     NOT NULL DEFAULT 'QUEUED',
    Attempts        TINYINT         NOT NULL DEFAULT 0,
    LastAttemptAt   DATETIMEOFFSET  NULL,
    SentAt          DATETIMEOFFSET  NULL,
    ErrorMessage    NVARCHAR(1000)  NULL,
    RelatedEntityType VARCHAR(60)   NULL,
    RelatedEntityID NVARCHAR(100)   NULL,
    CreatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_EmailQueue PRIMARY KEY CLUSTERED (EmailQueueID)
);
CREATE NONCLUSTERED INDEX IX_EmailQueue_Pending
    ON notify.EmailQueue (Status, CreatedAt)
    WHERE Status IN ('QUEUED','RETRY');
GO

-- ============================================================
-- 13. WORKFLOW / TASKS  (workflow schema)
-- ============================================================

-- 13.1  workflow.Task
CREATE TABLE workflow.Task (
    TaskID          UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantID        UNIQUEIDENTIFIER NOT NULL,
    TaskType        VARCHAR(60)     NOT NULL,   -- 'INTAKE_REVIEW','AUDIT_RESPONSE','ELIGIBILITY_CHECK'
    TaskTitle       NVARCHAR(300)   NOT NULL,
    TaskStatus      VARCHAR(30)     NOT NULL DEFAULT 'OPEN',
    Priority        VARCHAR(20)     NOT NULL DEFAULT 'NORMAL',
    AssignedToUserID UNIQUEIDENTIFIER NULL,
    AssignedToOrgID UNIQUEIDENTIFIER NULL,
    RelatedEntityType VARCHAR(60)   NULL,
    RelatedEntityID NVARCHAR(100)   NULL,
    PatientID       UNIQUEIDENTIFIER NULL,
    DueAt           DATETIMEOFFSET  NULL,
    CompletedAt     DATETIMEOFFSET  NULL,
    CompletedByUserID UNIQUEIDENTIFIER NULL,
    Notes           NVARCHAR(MAX)   NULL,
    CreatedByUserID UNIQUEIDENTIFIER NULL,
    CreatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    RowVersion      ROWVERSION      NOT NULL,
    CONSTRAINT PK_Task PRIMARY KEY CLUSTERED (TaskID),
    CONSTRAINT FK_Task_Tenant FOREIGN KEY (TenantID) REFERENCES core.Tenant (TenantID),
    CONSTRAINT FK_Task_Patient FOREIGN KEY (PatientID) REFERENCES patient.Patient (PatientID)
);
CREATE NONCLUSTERED INDEX IX_Task_Assigned
ON workflow.Task (AssignedToUserID, TaskStatus, DueAt)
WHERE TaskStatus <> 'COMPLETED'
  AND TaskStatus <> 'CANCELLED';
GO

-- 13.2  workflow.BackgroundJob
CREATE TABLE workflow.BackgroundJob (
    JobID           UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantID        UNIQUEIDENTIFIER NULL,
    JobType         VARCHAR(100)    NOT NULL,   -- 'ADHERENCE_CALC','ELIGIBILITY_BATCH','REFERRAL_IMPORT'
    JobStatus       VARCHAR(20)     NOT NULL DEFAULT 'QUEUED',
    PayloadJson     NVARCHAR(MAX)   NULL,
    ResultJson      NVARCHAR(MAX)   NULL,
    ScheduledAt     DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    StartedAt       DATETIMEOFFSET  NULL,
    CompletedAt     DATETIMEOFFSET  NULL,
    ErrorMessage    NVARCHAR(2000)  NULL,
    RetryCount      TINYINT         NOT NULL DEFAULT 0,
    MaxRetries      TINYINT         NOT NULL DEFAULT 3,
    CreatedByUserID UNIQUEIDENTIFIER NULL,
    CreatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_BackgroundJob PRIMARY KEY CLUSTERED (JobID)
);
CREATE NONCLUSTERED INDEX IX_Job_Pending
    ON workflow.BackgroundJob (JobType, JobStatus, ScheduledAt)
    WHERE JobStatus IN ('QUEUED','RETRY');
GO

-- 13.3  workflow.ApiIntegrationLog — Brightree, payer, device data logs
CREATE TABLE workflow.ApiIntegrationLog (
    ApiLogID        UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantID        UNIQUEIDENTIFIER NULL,
    IntegrationName VARCHAR(60)     NOT NULL,   -- 'BRIGHTREE','RESMED_AIRVIEW','BCBS_PORTAL'
    Direction       VARCHAR(10)     NOT NULL DEFAULT 'OUTBOUND',
    Endpoint        NVARCHAR(500)   NULL,
    RequestJson     NVARCHAR(MAX)   NULL,
    ResponseJson    NVARCHAR(MAX)   NULL,
    HttpStatus      SMALLINT        NULL,
    DurationMs      INT             NULL,
    IsSuccess       BIT             NOT NULL DEFAULT 0,
    ErrorMessage    NVARCHAR(1000)  NULL,
    RelatedEntityType VARCHAR(60)   NULL,
    RelatedEntityID NVARCHAR(100)   NULL,
    LoggedAt        DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_ApiIntegrationLog PRIMARY KEY CLUSTERED (ApiLogID)
);
GO

-- ============================================================
-- 14. REPORTING / KPI  (report schema)
-- ============================================================

-- 14.1  report.DashboardWidget — saved widget configurations per user
CREATE TABLE report.DashboardWidget (
    WidgetID        UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantID        UNIQUEIDENTIFIER NOT NULL,
    UserID          UNIQUEIDENTIFIER NOT NULL,
    WidgetType      VARCHAR(60)     NOT NULL,
    Title           NVARCHAR(200)   NULL,
    ConfigJson      NVARCHAR(MAX)   NULL,
    Position        TINYINT         NOT NULL DEFAULT 0,
    IsVisible       BIT             NOT NULL DEFAULT 1,
    CONSTRAINT PK_DashboardWidget PRIMARY KEY CLUSTERED (WidgetID),
    CONSTRAINT FK_Widget_User FOREIGN KEY (UserID) REFERENCES core.Users (UserID)
);
GO

-- 14.2  report.SavedReport
CREATE TABLE report.SavedReport (
    SavedReportID   UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantID        UNIQUEIDENTIFIER NOT NULL,
    CreatedByUserID UNIQUEIDENTIFIER NOT NULL,
    ReportName      NVARCHAR(200)   NOT NULL,
    Module          VARCHAR(60)     NOT NULL,
    QueryJson       NVARCHAR(MAX)   NOT NULL,   -- serialized filter/sort state
    IsShared        BIT             NOT NULL DEFAULT 0,
    ScheduleCron    NVARCHAR(60)    NULL,        -- NULL = on-demand
    LastRunAt       DATETIMEOFFSET  NULL,
    CreatedAt       DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_SavedReport PRIMARY KEY CLUSTERED (SavedReportID),
    CONSTRAINT FK_SavedReport_User FOREIGN KEY (CreatedByUserID) REFERENCES core.Users (UserID)
);
GO

-- 14.3  report.KpiSnapshot — pre-aggregated daily KPIs for dashboard performance
CREATE TABLE report.KpiSnapshot (
    KpiSnapshotID   BIGINT          NOT NULL IDENTITY(1,1),
    TenantID        UNIQUEIDENTIFIER NOT NULL,
    OrganizationID  UNIQUEIDENTIFIER NULL,
    SnapshotDate    DATE            NOT NULL,
    KpiKey          VARCHAR(80)     NOT NULL,   -- 'INBOX_ITEMS','AUDITS_DUE_TODAY','PENDING_REFUNDS'
    KpiValue        DECIMAL(18,4)   NULL,
    KpiValueText    NVARCHAR(200)   NULL,
    ComputedAt      DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_KpiSnapshot PRIMARY KEY CLUSTERED (KpiSnapshotID),
    CONSTRAINT UQ_KpiSnapshot UNIQUE (TenantID, OrganizationID, SnapshotDate, KpiKey)
);
CREATE NONCLUSTERED INDEX IX_KpiSnapshot_Lookup
    ON report.KpiSnapshot (TenantID, KpiKey, SnapshotDate DESC);
GO

-- ============================================================
-- 15. VIEWS
-- ============================================================

-- V1: Active patients with latest insurance
CREATE OR ALTER VIEW report.vw_ActivePatients AS
SELECT
    p.PatientID,
    p.TenantID,
    p.PatientNumber,
    p.FirstName,
    p.LastName,
    p.DateOfBirth,
    p.GenderCode,
    p.StateCode,
    p.MarketCode,
    p.Phone,
    p.Email,
    p.PatientStatus,
    ip.PayerName AS PrimaryPayerName,
    ip.PayerType AS PrimaryPayerType,
    pi.MemberID AS PrimaryMemberID
FROM patient.Patient p
LEFT JOIN patient.PatientInsurance pi
    ON pi.PatientID = p.PatientID AND pi.Priority = 1 AND pi.IsActive = 1
LEFT JOIN patient.InsurancePlan ip
    ON ip.InsurancePlanID = pi.InsurancePlanID
WHERE p.DeletedAt IS NULL AND p.IsActive = 1;
GO

-- V2: Inbox items across referrals + audit cases + tasks
CREATE OR ALTER VIEW report.vw_InboxItems AS
SELECT
    'REFERRAL'                  AS ItemType,
    CAST(r.ReferralID AS NVARCHAR(100)) AS ItemID,
    r.TenantID,
    r.AssignedToUserID,
    r.ReferralNumber            AS ReferenceNumber,
    'Referral: ' + ISNULL(r.IntakeFirstName,'') + ' ' + ISNULL(r.IntakeLastName,'') AS Title,
    r.ReferralStatus            AS StatusCode,
    r.Priority,
    r.ReceivedAt                AS CreatedAt
FROM intake.Referral r WHERE r.DeletedAt IS NULL AND r.ClosedAt IS NULL

UNION ALL

SELECT
    'AUDIT',
    CAST(a.AuditCaseID AS NVARCHAR(100)),
    a.TenantID,
    a.AssignedToUserID,
    a.CaseNumber,
    'Audit: ' + a.CaseNumber + ' · ' + ISNULL(a.PayerName,''),
    a.AuditStatus,
    CASE WHEN a.ResponseDeadline < CAST(GETDATE() AS DATE) THEN 'URGENT' ELSE 'NORMAL' END,
    a.CreatedAt
FROM audit.AuditCase a WHERE a.DeletedAt IS NULL AND a.AuditStatus NOT IN ('CLOSED')

UNION ALL

SELECT
    'TASK',
    CAST(t.TaskID AS NVARCHAR(100)),
    t.TenantID,
    t.AssignedToUserID,
    CAST(t.TaskID AS NVARCHAR(100)),
    t.TaskTitle,
    t.TaskStatus,
    t.Priority,
    t.CreatedAt
FROM workflow.Task t WHERE t.TaskStatus NOT IN ('COMPLETED','CANCELLED');
GO

-- V3: Adherence summary per patient
CREATE OR ALTER VIEW report.vw_AdherenceSummary AS
SELECT
    p.PatientID,
    p.TenantID,
    p.PatientNumber,
    p.FirstName,
    p.LastName,
    o.OrderID,
    o.OrderType,
    o.OrderStatus,
    s30.CompliancePct  AS Compliance30Day,
    s90.CompliancePct  AS Compliance90Day,
    s90.AdherenceStatusCode,
    s90.AvgUsageHours  AS AvgUsage90Day
FROM patient.Patient p
JOIN clinical.Orders o ON o.PatientID = p.PatientID AND o.DeletedAt IS NULL
LEFT JOIN clinical.AdherenceScore s30
    ON s30.PatientID = p.PatientID AND s30.OrderID = o.OrderID AND s30.PeriodDays = 30
    AND s30.PeriodEndDate = (
        SELECT MAX(x.PeriodEndDate) FROM clinical.AdherenceScore x
        WHERE x.PatientID = p.PatientID AND x.OrderID = o.OrderID AND x.PeriodDays = 30)
LEFT JOIN clinical.AdherenceScore s90
    ON s90.PatientID = p.PatientID AND s90.OrderID = o.OrderID AND s90.PeriodDays = 90
    AND s90.PeriodEndDate = (
        SELECT MAX(x.PeriodEndDate) FROM clinical.AdherenceScore x
        WHERE x.PatientID = p.PatientID AND x.OrderID = o.OrderID AND x.PeriodDays = 90)
WHERE p.DeletedAt IS NULL AND p.IsActive = 1;
GO

-- V4: Billing summary per patient
CREATE OR ALTER VIEW report.vw_BillingSummary AS
SELECT
    i.TenantID,
    i.PatientID,
    p.PatientNumber,
    p.FirstName + ' ' + p.LastName AS PatientName,
    COUNT(i.InvoiceID)             AS TotalInvoices,
    SUM(i.InvoiceAmount)           AS TotalBilled,
    SUM(i.PaidAmount)              AS TotalPaid,
    SUM(i.BalanceDue)              AS TotalBalance,
    SUM(CASE WHEN i.InvoiceStatus = 'UNDER_REVIEW' THEN i.BalanceDue ELSE 0 END) AS PendingRefunds
FROM billing.Invoice i
JOIN patient.Patient p ON p.PatientID = i.PatientID
WHERE i.DeletedAt IS NULL
GROUP BY i.TenantID, i.PatientID, p.PatientNumber, p.FirstName, p.LastName;
GO

-- ============================================================
-- 16. STORED PROCEDURES
-- ============================================================

-- SP1: Patient search (used in Patient Search & AuditShare step 1)
CREATE OR ALTER PROCEDURE patient.usp_SearchPatients
    @TenantID       UNIQUEIDENTIFIER,
    @FirstName      NVARCHAR(100)   = NULL,
    @LastName       NVARCHAR(100)   = NULL,
    @DateOfBirth    DATE            = NULL,
    @InsuranceMemberID NVARCHAR(100) = NULL,
    @PatientNumber  NVARCHAR(20)    = NULL,
    @PageNumber     INT             = 1,
    @PageSize       INT             = 25
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    SELECT
        p.PatientID,
        p.PatientNumber,
        p.FirstName,
        p.LastName,
        p.DateOfBirth,
        p.GenderCode,
        p.City,
        p.StateCode,
        ip.PayerName AS PrimaryPayer,
        pi.MemberID  AS InsuranceMemberID,
        COUNT(o.OrderID) AS ActiveOrderCount
    FROM patient.Patient p
    LEFT JOIN patient.PatientInsurance pi
        ON pi.PatientID = p.PatientID AND pi.Priority = 1 AND pi.IsActive = 1
    LEFT JOIN patient.InsurancePlan ip
        ON ip.InsurancePlanID = pi.InsurancePlanID
    LEFT JOIN clinical.Orders o
        ON o.PatientID = p.PatientID AND o.OrderStatus = 'ACTIVE' AND o.DeletedAt IS NULL
    WHERE
        p.TenantID = @TenantID
        AND p.DeletedAt IS NULL
        AND p.IsActive = 1
        AND (@FirstName IS NULL OR p.FirstName LIKE @FirstName + '%')
        AND (@LastName IS NULL OR p.LastName LIKE @LastName + '%')
        AND (@DateOfBirth IS NULL OR p.DateOfBirth = @DateOfBirth)
        AND (@InsuranceMemberID IS NULL OR pi.MemberID = @InsuranceMemberID)
        AND (@PatientNumber IS NULL OR p.PatientNumber = @PatientNumber)
    GROUP BY
        p.PatientID, p.PatientNumber, p.FirstName, p.LastName,
        p.DateOfBirth, p.GenderCode, p.City, p.StateCode,
        ip.PayerName, pi.MemberID
    ORDER BY p.LastName, p.FirstName
    OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
END;
GO

-- SP2: Patient Intake Processing
CREATE OR ALTER PROCEDURE intake.usp_ProcessReferralIntake
    @TenantID           UNIQUEIDENTIFIER,
    @ReferralID         UNIQUEIDENTIFIER,
    @AssignedUserID     UNIQUEIDENTIFIER,
    @ProcessedByUserID  UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Update referral status
        UPDATE intake.Referral
        SET ReferralStatus = 'IN_PROGRESS',
            AssignedToUserID = @AssignedUserID,
            UpdatedAt = SYSDATETIMEOFFSET()
        WHERE ReferralID = @ReferralID AND TenantID = @TenantID;

        -- Log status change
        INSERT INTO intake.ReferralStatusHistory
            (ReferralID, FromStatus, ToStatus, ChangedByUserID, Notes)
        VALUES
            (@ReferralID, 'NEW', 'IN_PROGRESS', @ProcessedByUserID, 'Assigned for processing');

        -- Create follow-up task
        INSERT INTO workflow.Task
            (TenantID, TaskType, TaskTitle, TaskStatus, Priority,
             AssignedToUserID, RelatedEntityType, RelatedEntityID)
        VALUES
            (@TenantID, 'INTAKE_REVIEW', 'Review and process referral',
             'OPEN', 'NORMAL', @AssignedUserID, 'Referral', CAST(@ReferralID AS NVARCHAR(100)));

        -- Audit log
        INSERT INTO audit.ActivityLog
            (TenantID, UserID, EntityType, EntityID, Action, Module)
        VALUES
            (@TenantID, @ProcessedByUserID, 'Referral',
             CAST(@ReferralID AS NVARCHAR(100)), 'ASSIGN', 'INTAKE');

        COMMIT TRANSACTION;
        SELECT 'SUCCESS' AS Result;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- SP3: Submit Audit Case (AuditShare step 4)
CREATE OR ALTER PROCEDURE audit.usp_SubmitAuditCase
    @AuditCaseID        UNIQUEIDENTIFIER,
    @SubmittedByUserID  UNIQUEIDENTIFIER,
    @OutcomeCode        VARCHAR(40) = NULL,
    @OutcomeNotes       NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @TenantID UNIQUEIDENTIFIER;
        DECLARE @OldStatus VARCHAR(30);

        SELECT @TenantID = TenantID, @OldStatus = AuditStatus
        FROM audit.AuditCase WHERE AuditCaseID = @AuditCaseID;

        IF @OldStatus = 'SUBMITTED'
        BEGIN
            RAISERROR('Audit case is already submitted.', 16, 1);
            RETURN;
        END;

        UPDATE audit.AuditCase
        SET AuditStatus = 'SUBMITTED',
            SubmittedAt = SYSDATETIMEOFFSET(),
            SubmittedByUserID = @SubmittedByUserID,
            Outcome = @OutcomeCode,
            OutcomeNotes = @OutcomeNotes,
            UpdatedAt = SYSDATETIMEOFFSET()
        WHERE AuditCaseID = @AuditCaseID;

        -- Lock all attached documents
        UPDATE audit.AuditCaseDocument
        SET IsLocked = 1
        WHERE AuditCaseID = @AuditCaseID;

        -- Status history
        INSERT INTO audit.AuditCaseStatusHistory
            (AuditCaseID, FromStatus, ToStatus, ChangedByUserID, Notes)
        VALUES (@AuditCaseID, @OldStatus, 'SUBMITTED', @SubmittedByUserID, 'Submitted to payer');

        -- Activity log
        INSERT INTO audit.ActivityLog
            (TenantID, UserID, EntityType, EntityID, Action, Module)
        VALUES
            (@TenantID, @SubmittedByUserID, 'AuditCase',
             CAST(@AuditCaseID AS NVARCHAR(100)), 'SUBMIT', 'AUDITSHARE');

        COMMIT TRANSACTION;
        SELECT 'SUCCESS' AS Result;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- SP4: Compute Adherence Score for a patient/order
CREATE OR ALTER PROCEDURE clinical.usp_ComputeAdherenceScore
    @PatientID  UNIQUEIDENTIFIER,
    @OrderID    UNIQUEIDENTIFIER,
    @PeriodDays TINYINT = 90
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EndDate DATE = CAST(GETDATE() AS DATE);
    DECLARE @StartDate DATE = DATEADD(DAY, -@PeriodDays, @EndDate);

    DECLARE @AvgUsage DECIMAL(5,2), @CompliantDays INT, @TotalDays INT,
            @CompPct DECIMAL(5,2), @StatusCode VARCHAR(20);

    SELECT
        @AvgUsage     = AVG(UsageHours),
        @CompliantDays = SUM(CASE WHEN UsageHours >= 4 THEN 1 ELSE 0 END),
        @TotalDays    = COUNT(1)
    FROM clinical.AdherenceRecord
    WHERE PatientID = @PatientID
      AND OrderID   = @OrderID
      AND RecordDate BETWEEN @StartDate AND @EndDate;

    SET @CompPct = CASE WHEN @TotalDays > 0
        THEN CAST(@CompliantDays AS DECIMAL(5,2)) / @TotalDays * 100
        ELSE NULL END;

    SET @StatusCode = CASE
        WHEN @CompPct >= 70 THEN 'COMPLIANT'
        WHEN @CompPct >= 50 THEN 'AT_RISK'
        ELSE 'NON_COMPLIANT' END;

    MERGE clinical.AdherenceScore AS target
    USING (
        SELECT @PatientID AS PatientID, @OrderID AS OrderID,
               @PeriodDays AS PeriodDays, @EndDate AS PeriodEndDate
    ) AS source ON (
        target.PatientID = source.PatientID
        AND target.OrderID = source.OrderID
        AND target.PeriodDays = source.PeriodDays
        AND target.PeriodEndDate = source.PeriodEndDate)
    WHEN MATCHED THEN
        UPDATE SET AvgUsageHours = @AvgUsage, CompliantDays = @CompliantDays,
                   TotalDays = @TotalDays, CompliancePct = @CompPct,
                   AdherenceStatusCode = @StatusCode, ComputedAt = SYSDATETIMEOFFSET()
    WHEN NOT MATCHED THEN
        INSERT (PatientID, OrderID, PeriodDays, PeriodEndDate, AvgUsageHours,
                CompliantDays, TotalDays, CompliancePct, AdherenceStatusCode)
        VALUES (@PatientID, @OrderID, @PeriodDays, @EndDate, @AvgUsage,
                @CompliantDays, @TotalDays, @CompPct, @StatusCode);

    SELECT @StatusCode AS AdherenceStatus, @CompPct AS CompliancePct,
           @AvgUsage AS AvgUsageHours, @CompliantDays AS CompliantDays,
           @TotalDays AS TotalDays;
END;
GO

-- SP5: Dashboard KPI snapshot (called nightly by SQL Agent job)
CREATE OR ALTER PROCEDURE report.usp_RefreshDashboardKpis
    @TenantID       UNIQUEIDENTIFIER,
    @SnapshotDate   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @SnapshotDate IS NULL SET @SnapshotDate = CAST(GETDATE() AS DATE);

    -- Inbox items
    MERGE report.KpiSnapshot AS t
    USING (SELECT @TenantID AS TenantID, NULL AS OrgID,
                  @SnapshotDate AS d, 'INBOX_ITEMS' AS k,
                  CAST(COUNT(1) AS DECIMAL)
           FROM report.vw_InboxItems
           WHERE TenantID = @TenantID) AS s(TenantID,OrgID,d,k,v)
    ON t.TenantID=s.TenantID AND ISNULL(t.OrganizationID,CAST('00000000-0000-0000-0000-000000000000' AS UNIQUEIDENTIFIER))=ISNULL(s.OrgID,CAST('00000000-0000-0000-0000-000000000000' AS UNIQUEIDENTIFIER)) AND t.SnapshotDate=s.d AND t.KpiKey=s.k
    WHEN MATCHED THEN UPDATE SET KpiValue=s.v, ComputedAt=SYSDATETIMEOFFSET()
    WHEN NOT MATCHED THEN INSERT (TenantID,OrganizationID,SnapshotDate,KpiKey,KpiValue) VALUES (s.TenantID,s.OrgID,s.d,s.k,s.v);

    -- Audits due today
    MERGE report.KpiSnapshot AS t
    USING (SELECT @TenantID, NULL, @SnapshotDate, 'AUDITS_DUE_TODAY',
                  CAST(COUNT(1) AS DECIMAL)
           FROM audit.AuditCase
           WHERE TenantID=@TenantID AND AuditStatus='OPEN'
             AND ResponseDeadline <= @SnapshotDate AND DeletedAt IS NULL) AS s(a,b,c,d,e)
    ON t.TenantID=s.a AND t.SnapshotDate=s.c AND t.KpiKey=s.d
    WHEN MATCHED THEN UPDATE SET KpiValue=s.e, ComputedAt=SYSDATETIMEOFFSET()
    WHEN NOT MATCHED THEN INSERT (TenantID,SnapshotDate,KpiKey,KpiValue) VALUES (s.a,s.c,s.d,s.e);
END;
GO

-- SP6: Approve Refund
CREATE OR ALTER PROCEDURE billing.usp_ApproveRefund
    @RefundID           UNIQUEIDENTIFIER,
    @ReviewedByUserID   UNIQUEIDENTIFIER,
    @Approved           BIT,
    @ReviewNotes        NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @NewStatus VARCHAR(30) = CASE WHEN @Approved = 1 THEN 'APPROVED' ELSE 'REJECTED' END;
        DECLARE @TenantID UNIQUEIDENTIFIER;

        UPDATE billing.Refund
        SET RefundStatus = @NewStatus,
            ReviewedByUserID = @ReviewedByUserID,
            ReviewedAt = SYSDATETIMEOFFSET(),
            ReviewNotes = @ReviewNotes
        WHERE RefundID = @RefundID;

        SELECT @TenantID = r.TenantID FROM billing.Invoice i
        JOIN billing.Refund r ON r.InvoiceID = i.InvoiceID
        WHERE r.RefundID = @RefundID;

        INSERT INTO audit.ActivityLog
            (TenantID, UserID, EntityType, EntityID, Action, Module)
        VALUES (@TenantID, @ReviewedByUserID, 'Refund',
                CAST(@RefundID AS NVARCHAR(100)), @NewStatus, 'BILLING');

        COMMIT TRANSACTION;
        SELECT @NewStatus AS Result;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- SP7: Soft-delete restore (generic)
CREATE OR ALTER PROCEDURE core.usp_RestoreSoftDelete
    @TableSchema    NVARCHAR(50),
    @TableName      NVARCHAR(100),
    @RecordID       NVARCHAR(100),
    @RestoredByUserID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql NVARCHAR(1000) =
        N'UPDATE [' + @TableSchema + N'].[' + @TableName + N'] '
        + N'SET DeletedAt = NULL WHERE ' + @TableName + N'ID = ''' + @RecordID + N'''';
    EXEC sp_executesql @Sql;
    INSERT INTO audit.ActivityLog (TenantID, UserID, EntityType, EntityID, Action, Module)
    SELECT NULL, @RestoredByUserID, @TableName, @RecordID, 'RESTORE', 'ADMIN';
END;
GO

-- ============================================================
-- 17. TRIGGERS
-- ============================================================

-- T1: Update UpdatedAt on Patient changes + write ChangeHistory
CREATE OR ALTER TRIGGER patient.trg_Patient_UpdateTimestamp
ON patient.Patient
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE patient.Patient
    SET UpdatedAt = SYSDATETIMEOFFSET()
    FROM patient.Patient p INNER JOIN inserted i ON p.PatientID = i.PatientID;
END;
GO

-- T2: Invoice status history auto-log on status change
CREATE OR ALTER TRIGGER billing.trg_Invoice_StatusChange
ON billing.Invoice
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO billing.InvoiceStatusHistory (InvoiceID, FromStatus, ToStatus, ChangedAt)
    SELECT d.InvoiceID, d.InvoiceStatus, i.InvoiceStatus, SYSDATETIMEOFFSET()
    FROM inserted i JOIN deleted d ON i.InvoiceID = d.InvoiceID
    WHERE i.InvoiceStatus <> d.InvoiceStatus;
END;
GO

-- T3: Audit case status history on status change
CREATE OR ALTER TRIGGER audit.trg_AuditCase_StatusChange
ON audit.AuditCase
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO audit.AuditCaseStatusHistory (AuditCaseID, FromStatus, ToStatus, ChangedAt)
    SELECT d.AuditCaseID, d.AuditStatus, i.AuditStatus, SYSDATETIMEOFFSET()
    FROM inserted i JOIN deleted d ON i.AuditCaseID = d.AuditCaseID
    WHERE i.AuditStatus <> d.AuditStatus;
END;
GO

-- ============================================================
-- 18. SCALAR FUNCTIONS
-- ============================================================

CREATE OR ALTER FUNCTION billing.fn_GetBalanceDue(@InvoiceID UNIQUEIDENTIFIER)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @Bal DECIMAL(12,2);
    SELECT @Bal = BalanceDue FROM billing.Invoice WHERE InvoiceID = @InvoiceID;
    RETURN ISNULL(@Bal, 0);
END;
GO

CREATE OR ALTER FUNCTION patient.fn_GetAge(@DateOfBirth DATE)
RETURNS TINYINT
AS
BEGIN
    RETURN DATEDIFF(YEAR, @DateOfBirth, GETDATE())
         - CASE WHEN MONTH(@DateOfBirth)*100+DAY(@DateOfBirth) > MONTH(GETDATE())*100+DAY(GETDATE()) THEN 1 ELSE 0 END;
END;
GO

-- ============================================================
-- 19. SQL AGENT JOB SUGGESTIONS (as comments)
-- ============================================================
/*
  Recommended SQL Agent Jobs:
  ----------------------------
  1. PatientPortal_AdherenceScoreBatch
     - Schedule: Nightly 2:00 AM
     - Calls: clinical.usp_ComputeAdherenceScore for all active CPAP/BiPAP orders

  2. PatientPortal_KpiRefresh
     - Schedule: Every 15 minutes during business hours
     - Calls: report.usp_RefreshDashboardKpis per tenant

  3. PatientPortal_EmailQueue_Process
     - Schedule: Every 2 minutes
     - Processes notify.EmailQueue WHERE Status IN ('QUEUED','RETRY')

  4. PatientPortal_ActivityLog_Archive
     - Schedule: Monthly
     - Moves rows older than 2 years from audit.ActivityLog to archive database

  5. PatientPortal_EligibilityCheck_Batch
     - Schedule: Nightly 3:00 AM
     - Batch eligibility calls for all active PatientInsurance records

  6. PatientPortal_BackgroundJob_Processor
     - Schedule: Every 30 seconds
     - Picks QUEUED jobs from workflow.BackgroundJob and dispatches to .NET workers
*/

-- ============================================================
-- END OF STRUCTURE SCRIPT
-- ============================================================