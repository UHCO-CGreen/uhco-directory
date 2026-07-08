component output="false" singleton {

    public any function init() {
        return this;
    }

    public array function getDeletionPolicy(boolean purgeDuplicatePairs = false) {
        var reviewSubmissionColumns = _getTableColumns("UserReviewSubmissions");
        var policy = [
            { label = "Published user images", sql = "DELETE FROM UserImages WHERE UserID = :id" },
            { label = "Generated image variants", sql = "DELETE FROM UserImageVariants WHERE UserImageSourceID IN (SELECT UserImageSourceID FROM UserImageSources WHERE UserID = :id)" },
            { label = "Image sources", sql = "DELETE FROM UserImageSources WHERE UserID = :id" },
            { label = "Organizations", sql = "DELETE FROM UserOrganizations WHERE UserID = :id" },
            { label = "Access assignments", sql = "DELETE FROM UserAccessAssignments WHERE UserID = :id" },
            { label = "Flag assignments", sql = "DELETE FROM UserFlagAssignments WHERE UserID = :id" },
            { label = "Addresses", sql = "DELETE FROM UserAddresses WHERE UserID = :id" },
            { label = "Academic info", sql = "DELETE FROM UserAcademicInfo WHERE UserID = :id" },
            { label = "External IDs", sql = "DELETE FROM UserExternalIDs WHERE UserID = :id" },
            { label = "Degrees", sql = "DELETE FROM UserDegrees WHERE UserID = :id" },
            { label = "Emails", sql = "DELETE FROM UserEmails WHERE UserID = :id" },
            { label = "Phones", sql = "DELETE FROM UserPhone WHERE UserID = :id" },
            { label = "Aliases", sql = "DELETE FROM UserAliases WHERE UserID = :id" },
            { label = "Bio", sql = "DELETE FROM UserBio WHERE UserID = :id" },
            { label = "Awards", sql = "DELETE FROM UserAwards WHERE UserID = :id" },
            { label = "Residencies", sql = "DELETE FROM UserResidency WHERE UserID = :id" },
            { label = "Student profile", sql = "DELETE FROM UserStudentProfile WHERE UserID = :id" }
        ];

        _appendUserReviewCleanupRules(policy, reviewSubmissionColumns);

        if (arguments.purgeDuplicatePairs) {
            arrayAppend(policy, {
                label = "Duplicate merge history",
                sql = "DELETE dum FROM DuplicateUserMerges dum INNER JOIN DuplicateUserPairs dup ON dup.PairID = dum.PairID WHERE dup.UserID_A = :id OR dup.UserID_B = :id"
            });
            arrayAppend(policy, {
                label = "Duplicate pairs",
                sql = "DELETE FROM DuplicateUserPairs WHERE UserID_A = :id OR UserID_B = :id"
            });
        }

        return policy;
    }

    public void function deleteUser(required numeric userID, boolean purgeDuplicatePairs = false) {
        var datasourceName = _getDatasourceName();
        var params = {
            id = { value = arguments.userID, cfsqltype = "cf_sql_integer" }
        };

        transaction {
            for (var rule in getDeletionPolicy(arguments.purgeDuplicatePairs)) {
                queryExecute(rule.sql, params, { datasource = datasourceName, timeout = 30 });
            }

            queryExecute(
                "DELETE FROM Users WHERE UserID = :id",
                params,
                { datasource = datasourceName, timeout = 30 }
            );
        }
    }

    private string function _getDatasourceName() {
        if (structKeyExists(request, "datasource") AND len(trim(request.datasource ?: ""))) {
            return request.datasource;
        }

        if (
            structKeyExists(application, "datasources")
            AND isStruct(application.datasources)
            AND structKeyExists(application.datasources, "admin")
        ) {
            return application.datasources.admin;
        }

        throw(type = "UserDeletion.MissingDatasource", message = "No admin datasource is available for user deletion.");
    }

    private void function _appendUserReviewCleanupRules(required array policy, required struct reviewSubmissionColumns) {
        var resolverSetClauses = [];
        var reviewerSetClauses = [];

        if (structKeyExists(arguments.reviewSubmissionColumns, "RESOLVEDBYADMINUSERID")) {
            arrayAppend(resolverSetClauses, "ResolvedByAdminUserID = NULL");
            if (structKeyExists(arguments.reviewSubmissionColumns, "RESOLVEDBYCOUGARNETID")) {
                arrayAppend(resolverSetClauses, "ResolvedByCougarnetID = NULL");
            }
            arrayAppend(arguments.policy, {
                label = "UserReview resolver references",
                sql = "UPDATE UserReviewSubmissions SET #arrayToList(resolverSetClauses, ', ')# WHERE ResolvedByAdminUserID = :id"
            });
        }

        if (structKeyExists(arguments.reviewSubmissionColumns, "REVIEWEDBYADMINUSERID")) {
            arrayAppend(reviewerSetClauses, "ReviewedByAdminUserID = NULL");
            if (structKeyExists(arguments.reviewSubmissionColumns, "REVIEWEDBYCOUGARNETID")) {
                arrayAppend(reviewerSetClauses, "ReviewedByCougarNetID = NULL");
            }
            arrayAppend(arguments.policy, {
                label = "UserReview reviewer references",
                sql = "UPDATE UserReviewSubmissions SET #arrayToList(reviewerSetClauses, ', ')# WHERE ReviewedByAdminUserID = :id"
            });
        }

        if (structKeyExists(arguments.reviewSubmissionColumns, "USERID")) {
            arrayAppend(arguments.policy, {
                label = "UserReview submissions",
                sql = "DELETE FROM UserReviewSubmissions WHERE UserID = :id"
            });
        }
    }

    private struct function _getTableColumns(required string tableName) {
        var columnMap = {};
        var results = queryExecute(
            "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = :tableName",
            {
                tableName = { value = arguments.tableName, cfsqltype = "cf_sql_nvarchar" }
            },
            { datasource = _getDatasourceName(), timeout = 30 }
        );

        for (var row in results) {
            columnMap[uCase(trim(row.COLUMN_NAME))] = true;
        }

        return columnMap;
    }
}