component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();
        return this;
    }

    public struct function getOpenSubmissionForUser(required numeric userID) {
        var qry = executeQueryWithRetry(
            "
            SELECT TOP 1 *
            FROM UserReviewSubmissions
            WHERE UserID = :userID
              AND Status = 'pending'
            ORDER BY SubmittedAt DESC, SubmissionID DESC
            ",
            { userID = { value=arguments.userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=5 }
        );
        var arr = queryToArray(qry);
        return arrayLen(arr) ? arr[1] : {};
    }

    public struct function getLatestReviewedSubmissionForUser(required numeric userID) {
        var qry = executeQueryWithRetry(
            "
            SELECT TOP 1 *
            FROM UserReviewSubmissions
            WHERE UserID = :userID
              AND Status IN ('approved', 'partially_approved', 'rejected')
            ORDER BY ISNULL(ReviewedAt, UpdatedAt) DESC, SubmissionID DESC
            ",
            { userID = { value=arguments.userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=5 }
        );
        var arr = queryToArray(qry);
        return arrayLen(arr) ? arr[1] : {};
    }

    public numeric function createSubmission(
        required numeric userID,
        required string cougarnetID,
        required string displayName,
        required string sectionList
    ) {
        var qry = executeQueryWithRetry(
            "
            INSERT INTO UserReviewSubmissions (
                UserID,
                CougarNetID,
                SubmittedByDisplayName,
                SectionList,
                Status,
                SubmittedAt,
                UpdatedAt
            )
            OUTPUT INSERTED.SubmissionID
            VALUES (
                :userID,
                :cougarnetID,
                :displayName,
                :sectionList,
                'pending',
                GETDATE(),
                GETDATE()
            )
            ",
            {
                userID = { value=arguments.userID, cfsqltype="cf_sql_integer" },
                cougarnetID = { value=arguments.cougarnetID, cfsqltype="cf_sql_nvarchar" },
                displayName = { value=arguments.displayName, cfsqltype="cf_sql_nvarchar" },
                sectionList = { value=arguments.sectionList, cfsqltype="cf_sql_nvarchar" }
            },
            { datasource=variables.datasource, timeout=30, fetchSize=5 }
        );
        return val(qry.SubmissionID ?: 0);
    }

    public void function deleteSubmission(required numeric submissionID) {
        executeQueryWithRetry(
            "DELETE FROM UserReviewSubmissions WHERE SubmissionID = :submissionID",
            { submissionID = { value=arguments.submissionID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public void function insertSubmissionField(
        required numeric submissionID,
        required string sectionKey,
        required string fieldName,
        required string fieldLabel,
        string currentValue = "",
        string proposedValue = "",
        numeric sortOrder = 0
    ) {
        executeQueryWithRetry(
            "
            INSERT INTO UserReviewSubmissionFields (
                SubmissionID,
                SectionKey,
                FieldName,
                FieldLabel,
                CurrentValue,
                ProposedValue,
                SortOrder
            )
            VALUES (
                :submissionID,
                :sectionKey,
                :fieldName,
                :fieldLabel,
                :currentValue,
                :proposedValue,
                :sortOrder
            )
            ",
            {
                submissionID = { value=arguments.submissionID, cfsqltype="cf_sql_integer" },
                sectionKey = { value=arguments.sectionKey, cfsqltype="cf_sql_nvarchar" },
                fieldName = { value=arguments.fieldName, cfsqltype="cf_sql_nvarchar" },
                fieldLabel = { value=arguments.fieldLabel, cfsqltype="cf_sql_nvarchar" },
                currentValue = { value=arguments.currentValue, cfsqltype="cf_sql_nvarchar" },
                proposedValue = { value=arguments.proposedValue, cfsqltype="cf_sql_nvarchar" },
                sortOrder = { value=arguments.sortOrder, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public struct function getSubmissionByID(required numeric submissionID) {
        var qry = executeQueryWithRetry(
            "
            SELECT s.*,
                   u.FirstName,
                   u.LastName,
                   u.EmailPrimary,
                   cg.ExternalValue AS LiveCougarNetID
            FROM UserReviewSubmissions s
            INNER JOIN Users u ON u.UserID = s.UserID
            OUTER APPLY (
                SELECT TOP 1 uei.ExternalValue
                FROM UserExternalIDs uei
                INNER JOIN ExternalSystems es ON es.SystemID = uei.SystemID
                WHERE uei.UserID = u.UserID
                  AND LOWER(es.SystemName) LIKE '%cougarnet%'
                  AND ISNULL(uei.ExternalValue, '') <> ''
                ORDER BY uei.SystemID
            ) cg
            WHERE s.SubmissionID = :submissionID
            ",
            { submissionID = { value=arguments.submissionID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=5 }
        );
        var arr = queryToArray(qry);
        return arrayLen(arr) ? arr[1] : {};
    }

    public array function getFieldsForSubmission(required numeric submissionID) {
        var qry = executeQueryWithRetry(
            "
            SELECT *
            FROM UserReviewSubmissionFields
            WHERE SubmissionID = :submissionID
            ORDER BY SortOrder, SubmissionFieldID
            ",
            { submissionID = { value=arguments.submissionID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=100 }
        );
        return queryToArray(qry);
    }

    public array function listSubmissions(string statusList = "") {
        var sql = "
            SELECT TOP 100
                   s.*, u.FirstName, u.LastName, u.EmailPrimary
            FROM UserReviewSubmissions s
            INNER JOIN Users u ON u.UserID = s.UserID
        ";
        var params = {};

        if (len(trim(arguments.statusList))) {
            var statusTokens = listToArray(arguments.statusList);
            var placeholders = [];
            var idx = 1;
            for (var token in statusTokens) {
                var paramName = "status#idx#";
                arrayAppend(placeholders, ":#paramName#");
                params[paramName] = { value=trim(token), cfsqltype="cf_sql_nvarchar" };
                idx++;
            }
            sql &= " WHERE s.Status IN (#arrayToList(placeholders, ',')#) ";
        }

        sql &= " ORDER BY CASE WHEN s.Status = 'pending' THEN 0 ELSE 1 END, s.SubmittedAt DESC, s.SubmissionID DESC";

        var qry = executeQueryWithRetry(
            sql,
            params,
            { datasource=variables.datasource, timeout=30, fetchSize=100 }
        );
        return queryToArray(qry);
    }

    public struct function getFieldByID(required numeric submissionFieldID) {
        var qry = executeQueryWithRetry(
            "SELECT * FROM UserReviewSubmissionFields WHERE SubmissionFieldID = :fieldID",
            { fieldID = { value=arguments.submissionFieldID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=5 }
        );
        var arr = queryToArray(qry);
        return arrayLen(arr) ? arr[1] : {};
    }

    public void function resolveField(
        required numeric submissionFieldID,
        required string resolution,
        required numeric resolvedByAdminUserID,
        required string resolvedByCougarnetID,
        string resolvedValue = ""
    ) {
        executeQueryWithRetry(
            "
            UPDATE UserReviewSubmissionFields
            SET Resolution = :resolution,
                ResolvedAt = GETDATE(),
                ResolvedByAdminUserID = :resolvedByAdminUserID,
                ResolvedByCougarnetID = :resolvedByCougarnetID,
                ResolvedValue = :resolvedValue
            WHERE SubmissionFieldID = :fieldID
            ",
            {
                resolution = { value=arguments.resolution, cfsqltype="cf_sql_nvarchar" },
                resolvedByAdminUserID = { value=arguments.resolvedByAdminUserID, cfsqltype="cf_sql_integer" },
                resolvedByCougarnetID = { value=arguments.resolvedByCougarnetID, cfsqltype="cf_sql_nvarchar" },
                resolvedValue = { value=arguments.resolvedValue, cfsqltype="cf_sql_nvarchar" },
                fieldID = { value=arguments.submissionFieldID, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public struct function getResolutionCounts(required numeric submissionID) {
        var qry = executeQueryWithRetry(
            "
            SELECT
                SUM(CASE WHEN Resolution IS NULL OR LTRIM(RTRIM(Resolution)) = '' THEN 1 ELSE 0 END) AS unresolved_count,
                SUM(CASE WHEN Resolution = 'approved' THEN 1 ELSE 0 END) AS approved_count,
                SUM(CASE WHEN Resolution = 'discarded' THEN 1 ELSE 0 END) AS discarded_count
            FROM UserReviewSubmissionFields
            WHERE SubmissionID = :submissionID
            ",
            { submissionID = { value=arguments.submissionID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=5 }
        );

        return {
            UNRESOLVED_COUNT = val(qry.unresolved_count ?: 0),
            APPROVED_COUNT = val(qry.approved_count ?: 0),
            DISCARDED_COUNT = val(qry.discarded_count ?: 0)
        };
    }

    public void function updateSubmissionReviewNote(
        required numeric submissionID,
        required string reviewNote
    ) {
        executeQueryWithRetry(
            "
            UPDATE UserReviewSubmissions
            SET ReviewNote = :reviewNote,
                UpdatedAt = GETDATE()
            WHERE SubmissionID = :submissionID
            ",
            {
                reviewNote = { value=arguments.reviewNote, cfsqltype="cf_sql_nvarchar" },
                submissionID = { value=arguments.submissionID, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public void function updateSubmissionStatus(
        required numeric submissionID,
        required string status,
        numeric reviewedByAdminUserID = 0,
        string reviewedByCougarnetID = "",
        string reviewNote = "",
        boolean preserveReviewNote = true
    ) {
        executeQueryWithRetry(
            "
            UPDATE UserReviewSubmissions
            SET Status = :status,
                ReviewNote = CASE WHEN :preserveReviewNote = 1 THEN ReviewNote ELSE :reviewNote END,
                UpdatedAt = GETDATE(),
                ReviewedAt = CASE WHEN :status = 'pending' THEN NULL ELSE GETDATE() END,
                ReviewedByAdminUserID = CASE WHEN :reviewedByAdminUserID > 0 THEN :reviewedByAdminUserID ELSE NULL END,
                ReviewedByCougarNetID = CASE WHEN LEN(:reviewedByCougarnetID) > 0 THEN :reviewedByCougarnetID ELSE NULL END
            WHERE SubmissionID = :submissionID
            ",
            {
                status = { value=arguments.status, cfsqltype="cf_sql_nvarchar" },
                reviewNote = { value=arguments.reviewNote, cfsqltype="cf_sql_nvarchar" },
                preserveReviewNote = { value=(arguments.preserveReviewNote ? 1 : 0), cfsqltype="cf_sql_bit" },
                reviewedByAdminUserID = { value=arguments.reviewedByAdminUserID, cfsqltype="cf_sql_integer" },
                reviewedByCougarnetID = { value=arguments.reviewedByCougarnetID, cfsqltype="cf_sql_nvarchar" },
                submissionID = { value=arguments.submissionID, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }
}