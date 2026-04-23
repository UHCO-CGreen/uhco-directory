component output="false" singleton {

    public any function init() {
        variables.EmailsDAO = createObject("component", "dao.emails_DAO").init();
        return this;
    }

    public struct function getEmails( required numeric userID ) {
        return { success=true, data=variables.EmailsDAO.getEmails( userID ) };
    }

    public void function replaceEmails( required numeric userID, required array emails ) {
        variables.EmailsDAO.replaceEmails( userID, emails );
    }

    public boolean function addEmailIfMissing(
        required numeric userID,
        required string emailAddress,
        string emailType = "UH"
    ) {
        return variables.EmailsDAO.addEmailIfMissing(argumentCollection=arguments);
    }

    public struct function getAllEmailsMap() {
        return variables.EmailsDAO.getAllEmailsMap();
    }
}
