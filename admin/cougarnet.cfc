<cfcomponent>
	
    <cffunction name="GetRoles" access="public" returntype="struct">
        
        	<cfquery name="luRoles">
            	SELECT *
            	FROM lu_Roles
        	</cfquery>
        
       		 <CFSET APPLICATION.OPT.ROLEDESCRIPT ="">
				<CFLOOP query="LUROLES">
					<cfset APPLICATION.OPT.ROLEDESCRIPT = listAppend(APPLICATION.OPT.ROLEDESCRIPT, "#LUROLES.ROLES#")>
				</CFLOOP>
            
				<cfquery name="luDepartments">
					SELECT *
					FROM lu_Departments
				</cfquery>
            
            <CFSET APPLICATION.OPT.DEPARTMENTS ="">
            <CFSET APPLICATION.OPT.ROLES ="">
            
            <CFLOOP query="LUDEPARTMENTS">
            	<cfset APPLICATION.OPT.DEPARTMENTS = listAppend(APPLICATION.OPT.DEPARTMENTS, "#LUDEPARTMENTS.DEPARTMENT#")>
            	<cfset APPLICATION.OPT.ROLES = listAppend(APPLICATION.OPT.ROLES, "#LUDEPARTMENTS.ROLES#")>
            </CFLOOP>
            
		<cfreturn application.opt>
	</cffunction>
	
	<cffunction name="LogUserIn" access="public" returntype="struct" >
		<cfargument name="USER" type="string" required="yes">
    	<cfargument name="PASS" type="string" required="yes">
    	<cfargument name="DOMAIN" type="string" required="yes" Default="COUGARNET">
        <cfargument name="root" type="string" required="yes" Default="">
    	<cftry>
    	<cfquery name="luDepartments">
            SELECT *
            FROM lu_Departments
        </cfquery>
            <cfset validDEPARTMENTS = ''>    
            <cfset validDEPARTMENTS = listAppend(validDepartments,"#luDepartments.Department#")>
            		
            <cfldap action="QUERY"          
			    name="GetUserInfo"          
			    attributes="displayName,memberOf,sAMAccountName,mail,telephoneNumber,accountExpires,userAccountControl,department,title,initials"          
			    start="DC=cougarnet,DC=uh,DC=edu"          
			    scope="SUBTREE"
			    filter="(&(objectClass=User)(objectCategory=Person)(samaccountname=#user#)(memberOf=CN=%OPTOMETRY,OU=Master Users,DC=cougarnet,DC=uh,DC=edu))"<!---filter="(&(objectClass=User)(objectCategory=Person)(samaccountname=#user#)(|(memberOf=CN=OPT-ASC,OU=ASC USERS,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu)(memberOf=CN=OPT-STAFF,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu)(memberOf=CN=OPT-OPTOMETRY,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu)(memberOf=CN=OPT-FACULTY-1,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu)(memberOf=CN=OPT-CLASS2020,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu)(memberOf=CN=OPT-CLASS2021,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu)(memberOf=CN=OPT-CLASS2022,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu)(memberOf=CN=OPT-CLASS2023,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu)(memberOf=CN=OPT-CLASS2024,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu)))"--->
				maxrows="1"          
			    server="cougarnet.uh.edu"          
			    username="#DOMAIN#\#USER#"          
			    password="#PASS#">  
                        
                        
            <cfset aa = left(GetUserInfo.accountexpires,9)/36>
            <cfset AccountExpiryDate = dateadd("h",(aa-24),"1601/01/01")>
            <CFSET SESSION.AUTH.ACCOUNTEXPIRES = AccountExpiryDate>
                    
                    
            <cfset SESSION.AUTH.AuthenticatedBy = "COUGARNET">
            <cfset SESSION.AUTH.isAuthenticated = "TRUE">
            <cfset SESSION.AUTH.isValidUser = "TRUE">
        	<CFSET SESSION.AUTH.FirstName  = "#ListLast(GetUserInfo.displayname, ",")#">
	        <CFSET SESSION.AUTH.LastName  = "#ListFirst(GetUserInfo.displayname, ",")#">
            <CFSET SESSION.AUTH.Email  = "#GetUserInfo.mail#">
                    
            <CFSET SESSION.AUTH.ADdepartment  = "#GetUserInfo.department#">
            <CFSET SESSION.AUTH.title  = "#GetUserInfo.title#">
            <CFSET SESSION.AUTH.initials  = "#GetUserInfo.initials#">
            <CFSET SESSION.AUTH.userAccountControl  = "#GetUserInfo.userAccountControl#">
                    
                    
            <CFSET SESSION.AUTH.user = "#GetUserInfo.samaccountname#">
            <CFSET SESSION.AUTH.phone = "#GetUserInfo.telephoneNumber#">
            <CFSET SESSION.AUTH.Name  = "#SESSION.AUTH.FirstName# #SESSION.AUTH.LastName#">
                    
                  
            <!---  LOOKUP USER AND ASSIGN PRIVILEGES --->      
	            <cfquery name="luAdmin_Users">
		            SELECT *
		            FROM UHCOUSERS
		            WHERE COUGARNET = '#SESSION.AUTH.user#'
		        </cfquery>
            
            	<cfif luAdmin_Users.RECORDCOUNT GT 0>
                	<cfquery name="luAdmin_DEPT">
		            	SELECT *
		            	FROM LU_DEPARTMENTS
		            	WHERE DEPARTMENTID = '#luAdmin_Users.departmentID#'
		        	</cfquery>
                    <cfquery name="luAdmin_ROLES">
		            	SELECT ROLES
		            	FROM LU_ROLES
		            	WHERE ROLESID = '#luAdmin_Users.Role#'
		        	</cfquery>
                    <cfset SESSION.AUTH.APPS = "#luAdmin_Users.Apps#">
                   	<CFSET SESSION.AUTH.USERID = "#luAdmin_Users.UHCOUSERID#">
                   	<cfset SESSION.AUTH.FIRSTTIME = '#luAdmin_Users.Firsttime#'>
                    <cfset SESSION.AUTH.TYPE = 'INTERNAL'>
                    <cfset SESSION.AUTH.ROLE = '#luAdmin_ROLES.Roles#'>
                    <cfset SESSION.AUTH.ROLEID = '#luAdmin_Users.Role#'> 
                    <cfset SESSION.AUTH.ISDIRECTOR = '#luAdmin_Users.isdirector#'>  
                    <cfset SESSION.AUTH.DEPARTMENTID = '#luAdmin_Users.departmentID#'>
					<cfset SESSION.AUTH.DEPARTMENT = '#luAdmin_DEPT.department#'>  
                    <cfset SESSION.AUTH.ISCOORDINATOR = '#luAdmin_Users.iscoordinator#'>
                    <cfset SESSION.AUTH.ISSTUDENT = '#luAdmin_Users.isstudent#'>              		
					<cfset SESSION.AUTH.MSG = 'User Authenticated With Privileges'>
                    <cfset SESSION.AUTH.CANREFER = '#luAdmin_Users.canREFER#'>
                    
                    <!--- Set User Preferences - Check to see if user has preferrences, if not create record and pull data--->
                    <cfquery name="lu_UHCOuserPrefs">
		            	SELECT *
		            	FROM UHCOusersPreferences
		            	WHERE uhcouserID = '#luAdmin_Users.UHCOUSERID#'
		        	</cfquery>
                    <cfif lu_UHCOuserPrefs.RECORDCOUNT IS 1>
                    <cfset SESSION.AUTH.PREFS.hideCONTACTED = #lu_UHCOuserPrefs.hideContacted#>
                    <cfset SESSION.AUTH.PREFS.defaultGrid = #lu_UHCOuserPrefs.defaultGrid#>
                    <cfelse>
                    <cfquery result="qPrefsResult">
                    INSERT INTO UHCOusersPreferences(UHCOuserID)
                    VALUES(#luAdmin_Users.UHCOUSERID#)                    
                    </cfquery>
                    <cfquery name="lu_UHCOuserPrefs">
		            	SELECT *
		            	FROM UHCOusersPreferences
		            	WHERE preferencesID = '#qPrefsResult.IDENTITYCOL#'
		        	</cfquery>
                    <cfset SESSION.AUTH.PREFS.hideCONTACTED = #lu_UHCOuserPrefs.hideContacted#>
                    <cfset SESSION.AUTH.PREFS.defaultGrid = #lu_UHCOuserPrefs.defaultGrid#>
                    </cfif>
                    
                    
                    
                    <Cfset SESSION.AUTH.DETAIL =''>
                    <cfif SESSION.AUTH.ROLEID IS 6>
                    <!--- Get Student Photo --->
                    <cfset student = getStudentPhoto(#session.auth.user#)>
                    <cfset SESSION.AUTH.PHOTOsrc = "#student.imageSRC#">
                    <cfset SESSION.AUTH.PHOTO = "#student.imageURL#">
                    <cfset SESSION.AUTH.GRADYEAR = "#student.GRADYEAR#">
                    
					<cfelseif SESSION.AUTH.ROLEID IS 7>
                    <!--- Get Faculty Photo --->
                    
                    <cfset faculty = getFacultyPhoto(#luAdmin_Users.facultyID#)>
                    <cfset SESSION.AUTH.PHOTOsrc = "">
					<cfset SESSION.AUTH.PHOTO = "#faculty.imageURL#">
                    <cfelse>
                    <cfif session.auth.user IS 'wcgreen'>
					  <cfset img = 'deadpool_12.jpg'>
                    <cfelse>
                    <cfif session.auth.roleid is 9>
                    	<cfset img = 'njoy-vision.jpg'>
                    <cfelse>
                    	<cfset img = 'coog.jpg'>
                    </cfif>
                    </cfif>
                    <cfset SESSION.AUTH.PHOTOsrc = "">
                    <cfset SESSION.AUTH.PHOTO = "#root#/dist/img/#img#">
                    </cfif>
                <cfelse>
				    <CFSET SESSION.AUTH.USERID = "#luAdmin_Users.UHCOUSERID#">
                   	<cfset SESSION.AUTH.FIRSTTIME = 'N/A'>
                    <cfset SESSION.AUTH.TYPE = 'INTERNAL'>
                    <cfset img = 'coog.jpg'>
                    
                    <cfset SESSION.AUTH.PHOTOsrc = "">
                    <cfset SESSION.AUTH.PHOTO = "#root#/dist/img/#img#">
                    <cfset SESSION.AUTH.ROLEid = '5'> 
					<cfset SESSION.AUTH.ROLE = 'Referral Only'>  
                    <cfset SESSION.AUTH.ISDIRECTOR = 'No'>  
                    <cfset SESSION.AUTH.DEPARTMENT = 'None'>
                    <cfset SESSION.AUTH.DEPARTMENTID = '0'> 
                    <cfset SESSION.AUTH.ISCOORDINATOR = 'NO'>
                    <cfset SESSION.AUTH.MSG = 'User Authenticated With No Privileges'>
                    <cfset SESSION.AUTH.CANREFER = '1'>
                    <Cfset SESSION.AUTH.DETAIL ='User may submit a referral, ASC Assistance Call or Repair/IT request'>
                </cfif>
            	
                
                
                
           
    <cfloginuser
	   name = "#SESSION.AUTH.USER#"
	   password = "#FORM.PASS#"
	   roles = "#SESSION.AUTH.ROLE#">
           
            <cfcatch type="ANY">              
         		<cfset SESSION.AUTH.isAuthenticated = "FALSE">
				<cfset SESSION.AUTH.PermissionOf = "">
				<cfset SESSION.AUTH.isValidUser = "FALSE">
				<cfset SESSION.AUTH.MSG = "#cfcatch.message#">
				<cfif cfcatch.message CONTAINS 'error code 49'>
					<cfif cfcatch.message CONTAINS '52e'>
						<cfset SESSION.AUTH.DETAIL = "Error 52e: Invalid Credentials, Please check your Username Or Password and try again">
					<cfelseif cfcatch.message CONTAINS '525'>
						<cfset SESSION.AUTH.DETAIL = "Error 525: User Not Found, Please check your Username and try again">
					<cfelseif cfcatch.message CONTAINS '530'>
						<cfset SESSION.AUTH.DETAIL = "Error 530: Not Permitted To Logon At This Time, Please contact your IT Admin">
					<cfelseif cfcatch.message CONTAINS '532'>
						<cfset SESSION.AUTH.DETAIL = "Error 532: Password Expired, Please change your password before attempting to login again">
					<cfelseif cfcatch.message CONTAINS '533'>
						<cfset SESSION.AUTH.DETAIL = "Error 533: Account Disabled,  Please contact your IT admin">
					<cfelseif cfcatch.message CONTAINS '701'>
						<cfset SESSION.AUTH.DETAIL = "Error 701: Account Expired, Please contact your IT admin">
					<cfelseif cfcatch.message CONTAINS '773'>
						<cfset SESSION.AUTH.DETAIL = "Error 773: User Must Reset Password, Please reset your password before attempting to login again">
					<cfelse>
						<cfset SESSION.AUTH.DETAIL = "Login Attempt Failed For Unknown Reason, Please try again... #cfcatch.message# <br/> #cfcatch.detail#">
					</cfif>
				<cfelse>
					<cfset SESSION.AUTH.DETAIL = "Login Attempt Failed For Unknown Reason, Please try again... #cfcatch.message# <Br/> #cfcatch.detail#">
				</cfif>   
      		</cfcatch>
    	</cftry>
    	<cfreturn session.auth>
	</cffunction>
    
    
</cfcomponent>