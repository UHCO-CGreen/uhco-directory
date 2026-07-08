component output="false" singleton {

    public any function init() {
        variables.PhoneDAO = createObject("component", "dao.phone_DAO").init();
        return this;
    }

    public struct function getPhones( required numeric userID ) {
        return { success=true, data=variables.PhoneDAO.getPhones( userID ) };
    }

    public void function replacePhones( required numeric userID, required array phones ) {
        variables.PhoneDAO.replacePhones( userID, phones );
    }

    public struct function getAllUserPhonesMap() {
        return variables.PhoneDAO.getAllPrimaryPhonesMap();
    }
}
