<cfcomponent displayname="DirectoryService" output="false" hint="CFC for interacting with UH Directory API">

    <!--- Base API URL --->
    <cfset variables.baseUrl = "https://api.uh.edu/directory/v1/">

    <!--- Default params for your use case --->
    <cfset variables.defaultDivision = "H0412">
    <cfset variables.defaultCampus  = "HR730">

    <!--- Token, Secret, and Auth Code --->
    <cfset variables.apiToken = "">
    <cfset variables.apiSecret = "">
    <cfset variables.authCode = ""> <!-- This is the "auth" returned by /auth -->



    <!--- Initialize: Accept both token AND secret for /auth --->
    <cffunction name="init" access="public" returntype="any" output="true">
        <cfargument name="apiToken" type="string" required="true">
        <cfargument name="apiSecret" type="string" required="true">

        <cfset variables.apiToken  = encodeForURL(arguments.apiToken)>
        <cfset variables.apiSecret = encodeForURL(arguments.apiSecret)>

        <!-- Immediately authenticate to fetch auth code -->
        <cfset authenticate()>

        <cfreturn this>
    </cffunction>



    <!--- AUTHENTICATE: Exchange token + secret for auth code --->
    <cffunction name="authenticate" access="private" returntype="void" output="true">
        <cfset var url = variables.baseUrl & "auth?token=" & variables.apiToken & "&secret=" & variables.apiSecret>
        <cfset var httpResp = "">
        <cfset var data = "">

        <cfhttp url="#url#" method="get" timeout="20" result="httpResp"></cfhttp>

        <!-- Check for success - handle both "200" and "200 OK" formats -->
        <cfset var statusOk = false>
        <cfif left(httpResp.statusCode, 3) EQ "200">
            <cfset statusOk = true>
        </cfif>

        <!-- Expecting { "data" : { "auth" : "value" } } -->
        <cfif statusOk>
            <cftry>
                <cfset data = deserializeJSON(httpResp.fileContent)>
                
                <!-- Check for data.auth (nested structure) -->
                <cfif structKeyExists(data, "data") AND isStruct(data.data) AND structKeyExists(data.data, "auth")>
                    <cfset variables.authCode = data.data.auth>
                <!-- Fallback: check for root-level auth (older API format) -->
                <cfelseif structKeyExists(data, "auth")>
                    <cfset variables.authCode = data.auth>
                <cfelse>
                </cfif>
            <cfcatch type="any">
            </cfcatch>
            </cftry>
        <cfelse>
        </cfif>

        <!-- If failed, ensure we don't use an old code -->
        <cfif NOT len(variables.authCode)>
            <cfset variables.authCode = "">
        </cfif>
    </cffunction>



    <!--- Helper: Get current authentication status --->
    <cffunction name="getAuthStatus" access="public" returntype="struct">
        <cfset var status = structNew()>
        <cfset status.isAuthenticated = len(variables.authCode) GT 0>
        <cfset status.hasAuthCode = len(variables.authCode) GT 0>
        <cfset status.authCodeLength = len(variables.authCode)>
        <cfset status.message = "">

        <cfif status.isAuthenticated>
            <cfset status.message = "Authenticated - Auth code is present">
        <cfelse>
            <cfset status.message = "NOT authenticated - No auth code available">
        </cfif>

        <cfreturn status>
    </cffunction>



    <!--- Internal request wrapper --->
    <cffunction name="apiRequest" access="private" returntype="struct" output="true">
        <cfargument name="endpoint" type="string" required="true">
        <cfargument name="params" type="struct" required="false" default="#structNew()#">
        <cfargument name="returnJson" type="boolean" default="false">
        <cfargument name="useAuth" type="boolean" default="false">

        <cfset var url = variables.baseUrl & arguments.endpoint & "?token=" & variables.apiToken>
        <cfset var authCodePresent = false>
        <cfset var authenticated = false>
        <cfset var authMessage = "">

        <!-- Include auth code when needed -->
        <cfif arguments.useAuth AND len(variables.authCode)>
            <cfset url &= "&auth=" & variables.authCode>
            <cfset authCodePresent = true>
            <cfset authMessage = "Auth code included in request">
        <cfelse>
            <cfif arguments.useAuth>
                <cfset authMessage = "Auth requested but NO auth code available">
            <cfelse>
                <cfset authMessage = "Auth not requested (public endpoint)">
            </cfif>
        </cfif>

        <!-- Append user params -->
        <cfset var keyArray = structKeyArray(arguments.params)>
        <cfloop array="#keyArray#" index="key">
            <cfset url &= "&" & lcase(key) & "=" & encodeForURL(arguments.params[key])>
        </cfloop>

        <!-- Build display URL with auth redacted (used in result struct) -->
        <cfset var displayUrl = reReplaceNoCase(url, "(&auth=)[^&]+", "\1[REDACTED]", "ONE")>

        <!-- Make request -->
        <cfhttp url="#url#" method="get" timeout="20" result="httpResp"></cfhttp>

        <!-- If unauthorized, re-auth and retry once -->
        <cfif listFind("401,403", httpResp.statusCode)>
            <cfset authenticate()>
            <cfset url = variables.baseUrl & arguments.endpoint & "?token=" & variables.apiToken>
            <cfset authCodePresent = false>
            <cfset authMessage = "Re-authentication attempted">

            <cfif arguments.useAuth AND len(variables.authCode)>
                <cfset url &= "&auth=" & variables.authCode>
                <cfset authCodePresent = true>
                <cfset authMessage = "Auth code included after re-auth">
            </cfif>

            <cfloop array="#keyArray#" index="key">
                <cfset url &= "&" & lcase(key) & "=" & encodeForURL(arguments.params[key])>
            </cfloop>

            <cfhttp url="#url#" method="get" timeout="20" result="httpResp"></cfhttp>
        </cfif>

        <!-- Check if this was an authenticated successful request -->
        <!-- Handle both "200" and "200 OK" status formats -->
        <cfset var statusCodeNum = left(httpResp.statusCode, 3)>
        <cfif authCodePresent AND listFind("200,201,204", statusCodeNum)>
            <cfset authenticated = true>
        </cfif>

        <!-- Build return struct -->
        <cfset var result = structNew()>
        <cfset result.authenticated  = authenticated>
        <cfset result.statusCode     = httpResp.statusCode>
        <cfset result.authCodePresent = authCodePresent>
        <cfset result.authMessage    = authMessage>
        <cfset result.requestUrl     = reReplaceNoCase(displayUrl, "(&auth=)[^&]+", "\1[REDACTED]", "ONE")>

        <!-- Raw JSON or parsed data -->
        <cfif arguments.returnJson>
            <cfset result.data = httpResp.fileContent>
        <cfelse>
            <cfset result.data = deserializeJSON(httpResp.fileContent)>
        </cfif>

        <cfreturn result>
    </cffunction>



    <!--- GET: Departments (public) --->
    <cffunction name="getDepartments" access="public" returntype="struct">
        <cfargument name="returnJson" type="boolean" default="false">
        <cfset var response = apiRequest(
            "departments",
            { campus = variables.defaultCampus, division = variables.defaultDivision },
            arguments.returnJson,
            false
        )>
        <cfreturn response>
    </cffunction>



    <!--- GET: Offices (public) --->
    <cffunction name="getOffices" access="public" returntype="struct">
        <cfargument name="returnJson" type="boolean" default="false">
        <cfset var response = apiRequest(
            "offices",
            { campus = variables.defaultCampus, division = variables.defaultDivision },
            arguments.returnJson,
            false
        )>
        <cfreturn response>
    </cffunction>



    <!--- GET: Office (public) --->
    <cffunction name="getOffice" access="public" returntype="struct">
        <cfargument name="officeId" type="string" required="true">
        <cfargument name="returnJson" type="boolean" default="false">
        <cfset var response = apiRequest(
            "office",
            { id = arguments.officeId },
            arguments.returnJson,
            false
        )>
        <cfreturn response>
    </cffunction>



    <!--- GET: People (restricted requires auth) --->
    <cffunction name="getPeople" access="public" returntype="struct">
        <cfargument name="returnJson"  type="boolean" default="false">
        <cfargument name="student"     type="boolean" default="false">
        <cfargument name="staff"       type="boolean" default="false">
        <cfargument name="faculty"     type="boolean" default="false">
        <cfargument name="division"    type="string"  default="">
        <cfargument name="department"  type="string"  default="">
        <cfargument name="q"           type="string"  default="">

        <cfif NOT (arguments.student OR arguments.staff OR arguments.faculty)>
            <cfthrow type="Client" message="getPeople requires at least one of student/staff/faculty=true" detail="Use getPeople(student=true), getPeople(staff=true), or getPeople(faculty=true)" />
        </cfif>

        <cfset var filters = structNew()>
        <cfset filters.campus = variables.defaultCampus>
        <cfif len(trim(arguments.division))>
            <cfset filters.division = trim(arguments.division)>
        </cfif>
        <cfif len(trim(arguments.department))>
            <cfset filters.department = trim(arguments.department)>
        </cfif>
        <cfif len(trim(arguments.q))>
            <cfset filters.q = trim(arguments.q)>
        </cfif>
        <cfif arguments.student>
            <cfset filters.student = "true">
        </cfif>
        <cfif arguments.staff>
            <cfset filters.staff = "true">
        </cfif>
        <cfif arguments.faculty>
            <cfset filters.faculty = "true">
        </cfif>

        <cfset var response = apiRequest(
            "people",
            filters,
            arguments.returnJson,
            true
        )>
        <cfreturn response>
    </cffunction>



    <!--- GET: Person (restricted requires auth) --->
    <cffunction name="getPerson" access="public" returntype="struct">
        <cfargument name="personId" type="string" required="true">
        <cfargument name="returnJson" type="boolean" default="false">
        <cfset var response = apiRequest(
            "person",
            { id = arguments.personId },
            arguments.returnJson,
            true
        )>
        <cfreturn response>
    </cffunction>



     <!--- GET: People from XML file --->
    <cffunction name="getPeopleFromXml" access="public" returntype="any">
        <cfargument name="returnJson" type="boolean" default="false">
        <cfargument name="student" type="boolean" default="false">
        <cfargument name="staff" type="boolean" default="false">
        <cfargument name="faculty" type="boolean" default="false">

        <cfif NOT (arguments.student OR arguments.staff OR arguments.faculty)>
            <cfthrow type="Client" message="getPeopleFromXml requires at least one of student/staff/faculty=true" detail="Use getPeopleFromXml(student=true), getPeopleFromXml(staff=true), or getPeopleFromXml(faculty=true)" />
        </cfif>

        <cfset var xmlPath = expandPath("/dir/xml/mc-dir.xml")>
        <cfset var xmlContent = fileRead(xmlPath)>
        <cfset var peopleArray = arrayNew(1)>
        
        <cftry>
            <!--- Create a proper XML structure with declaration --->
            <cfset var xmlContent = trim(xmlContent)>
            <cfif not left(xmlContent, 5) eq "<?xml">
                <cfset xmlContent = '<?xml version="1.0" encoding="UTF-8"?>' & xmlContent>
            </cfif>
            
            <cfset var xmlDoc = xmlParse(xmlContent)>
            <cfset var items = xmlDoc.dmc.items.xmlChildren>
            
            <!--- Loop through each item and convert to struct --->
            <cfloop array="#items#" index="item">
                <cfset var person = structNew()>
                <cfset var ut = "">
                <cfif structKeyExists(item, "usertype")>
                    <cfset ut = trim(lcase(item.usertype.xmlText))>
                </cfif>

                <cfset var include = false>
                <cfif arguments.student AND ut eq "student">
                    <cfset include = true>
                </cfif>
                <cfif arguments.staff AND ut eq "staff">
                    <cfset include = true>
                </cfif>
                <cfif arguments.faculty AND ut eq "faculty">
                    <cfset include = true>
                </cfif>

                <cfif NOT include>
                    <cfcontinue>
                </cfif>

                <!--- Extract common fields --->
                <cfif structKeyExists(item, "firstname")>
                    <cfset person.firstname = item.firstname.xmlText>
                </cfif>
                <cfif structKeyExists(item, "lastname")>
                    <cfset person.lastname = item.lastname.xmlText>
                </cfif>
                <cfif structKeyExists(item, "email")>
                    <cfset person.email = item.email.xmlText>
                </cfif>
                <cfif structKeyExists(item, "phone")>
                    <cfset person.phone = item.phone.xmlText>
                </cfif>
                <cfif structKeyExists(item, "title")>
                    <cfset person.title = item.title.xmlText>
                </cfif>
                <cfif structKeyExists(item, "department")>
                    <cfset person.department = item.department.xmlText>
                    <cfset person.division = variables.defaultDivision>
                </cfif>
                <cfif structKeyExists(item, "office")>
                    <cfset person.office = item.office.xmlText>
                </cfif>
                <cfif structKeyExists(item, "usertype")>
                    <cfset person.usertype = item.usertype.xmlText>
                </cfif>
                
                <cfset arrayAppend(peopleArray, person)>
            </cfloop>
            
            <cfcatch>
                <cfset peopleArray = arrayNew(1)>
                <cfset arrayAppend(peopleArray, {"error": "Error parsing XML: " & cfcatch.message})>
            </cfcatch>
        </cftry>

        <!--- Return JSON if requested --->
        <cfif arguments.returnJson>
            <cfreturn serializeJSON(peopleArray)>
        </cfif>

        <cfreturn peopleArray>
    </cffunction>


    <!--- Lookup person by first/last/email (fallback) --->
    <cffunction name="getPersonByDetails" access="public" returntype="struct">
        <cfargument name="firstName" type="string" required="true">
        <cfargument name="lastName" type="string" required="true">
        <cfargument name="email" type="string" required="true">

        <cfset var peopleResponse = getPeople(false, true, true, true)>
        <cfset var allPeople = peopleResponse.data>
        <cfset var candidate = structNew()>

        <cfif isArray(allPeople)>
            <cfloop array="#allPeople#" index="p">
                <cfif structKeyExists(p,"firstname") AND structKeyExists(p,"lastname") AND structKeyExists(p,"email")>
                    <cfif compareNoCase(trim(p.firstname), trim(arguments.firstName)) eq 0
                            AND compareNoCase(trim(p.lastname), trim(arguments.lastName)) eq 0
                            AND compareNoCase(trim(p.email), trim(arguments.email)) eq 0>
                        <cfset candidate = p>
                        <cfbreak>
                    </cfif>
                </cfif>
            </cfloop>
        </cfif>

        <cfreturn candidate>
    </cffunction>


    <!--- Helper: check if person exists in getPeople by first/last/email --->
    <cffunction name="personExistsInPeople" access="public" returntype="boolean">
        <cfargument name="person" type="struct" required="true">

        <cfset var peopleResponse = getPeople(false, true, true, true)>
        <cfset var allPeople = peopleResponse.data>
        <cfset var exists = false>

        <cfif isArray(allPeople) AND structKeyExists(arguments.person, 'firstname') AND structKeyExists(arguments.person, 'lastname') AND structKeyExists(arguments.person, 'email')>
            <cfloop array="#allPeople#" index="p">
                <cfif structKeyExists(p, 'firstname') AND structKeyExists(p, 'lastname') AND structKeyExists(p, 'email')>
                    <cfif compareNoCase(trim(p.firstname), trim(arguments.person.firstname)) eq 0
                            AND compareNoCase(trim(p.lastname), trim(arguments.person.lastname)) eq 0
                            AND compareNoCase(trim(p.email), trim(arguments.person.email)) eq 0>
                        <cfset exists = true>
                        <cfbreak>
                    </cfif>
                </cfif>
            </cfloop>
        </cfif>

        <cfreturn exists>
    </cffunction>


    <!--- Compare: People from API but NOT in XML --->
    <cffunction name="getPeopleNotInXml" access="public" returntype="any">
        <cfargument name="returnJson" type="boolean" default="false">
        <cfargument name="student" type="boolean" default="false">
        <cfargument name="staff" type="boolean" default="false">
        <cfargument name="faculty" type="boolean" default="false">
        <cfargument name="verifyPerson" type="boolean" default="true">

        <cfset var apiResponse = getPeople(false, arguments.student, arguments.staff, arguments.faculty)>
        <cfset var apiPeople = apiResponse.data>
        <cfset var xmlPeople = getPeopleFromXml(returnJson=false, student=arguments.student, staff=arguments.staff, faculty=arguments.faculty)>
        <cfset var notInXml = arrayNew(1)>
        <cfset var xmlEmails = arrayNew(1)>
        
        <cfoutput><p><strong>getPeopleNotInXml - API Authentication Status:</strong> #yesNoFormat(apiResponse.authenticated)# | #apiResponse.authMessage#</p></cfoutput>
        
        <!--- Build array of XML emails for comparison --->
        <cfloop array="#xmlPeople#" index="person">
            <cfif structKeyExists(person, "email") and person.email neq "">
                <cfset arrayAppend(xmlEmails, lcase(person.email))>
            </cfif>
        </cfloop>
        
        <!--- Find API records not in XML --->
        <cfif isArray(apiPeople)>
            <cfloop array="#apiPeople#" index="person">
                <cfif structKeyExists(person, "email") and person.email neq "">
                    <cfif not arrayContains(xmlEmails, lcase(person.email))>
                        <cfset arrayAppend(notInXml, person)>
                    </cfif>
                </cfif>
            </cfloop>
        </cfif>

        <!--- Verify with getPeople/getPerson fallback --->
        <cfset var verifiedNotInXml = arrayNew(1)>
        <cfloop array="#notInXml#" index="person">
            <cfset var existsInPeople = personExistsInPeople(person)>
            <cfset var existsInPerson = false>

            <cfif arguments.verifyPerson>
                <!--- first try by id if available --->
                <cfif structKeyExists(person, 'id') and len(trim(person.id))>
                    <cftry>
                        <cfset var pResponse = getPerson(person.id, false)>
                        <cfset var p = pResponse.data>
                        <cfif isStruct(p) AND structKeyExists(p, 'id')>
                            <cfset existsInPerson = true>
                        </cfif>
                    <cfcatch>
                    </cfcatch>
                    </cftry>
                </cfif>

                <!--- fallback by details if not found yet --->
                <cfif NOT existsInPerson AND structKeyExists(person,'firstname') AND structKeyExists(person,'lastname') AND structKeyExists(person,'email')>
                    <cfset var candidate = getPersonByDetails(person.firstname, person.lastname, person.email)>
                    <cfif structKeyExists(candidate, 'email')>
                        <cfset existsInPerson = true>
                    </cfif>
                </cfif>
            </cfif>

            <cfif NOT existsInPeople AND NOT existsInPerson>
                <cfset arrayAppend(verifiedNotInXml, person)>
            </cfif>
        </cfloop>

        <!--- Return JSON if requested --->
        <cfif arguments.returnJson>
            <cfreturn serializeJSON(verifiedNotInXml)>
        </cfif>

        <cfreturn verifiedNotInXml>
    </cffunction>


    <!--- GET: Generic record count helper --->
    <cffunction name="getRecordCount" access="public" returntype="numeric">
        <cfargument name="dataset" required="true" type="any">

        <cfif isArray(arguments.dataset)>
            <cfreturn arrayLen(arguments.dataset)>
        </cfif>

        <cfif isStruct(arguments.dataset)>
            <cfif structKeyExists(arguments.dataset, "count")>
                <cfreturn val(arguments.dataset.count)>
            </cfif>
            <cfif structKeyExists(arguments.dataset, "total")>
                <cfreturn val(arguments.dataset.total)>
            </cfif>
            <cfif structKeyExists(arguments.dataset, "records") AND isArray(arguments.dataset.records)>
                <cfreturn arrayLen(arguments.dataset.records)>
            </cfif>
            <cfif structKeyExists(arguments.dataset, "items") AND isArray(arguments.dataset.items)>
                <cfreturn arrayLen(arguments.dataset.items)>
            </cfif>
            <cfif structKeyExists(arguments.dataset, "data") AND isArray(arguments.dataset.data)>
                <cfreturn arrayLen(arguments.dataset.data)>
            </cfif>
            <cfif structKeyExists(arguments.dataset, "people") AND isArray(arguments.dataset.people)>
                <cfreturn arrayLen(arguments.dataset.people)>
            </cfif>
            <cfreturn structCount(arguments.dataset)>
        </cfif>

        <cfreturn 0>
    </cffunction>


    <!--- Compare: People from XML but NOT in API --->
    <cffunction name="getXmlPeopleNotInApi" access="public" returntype="any">
        <cfargument name="returnJson" type="boolean" default="false">
        <cfargument name="student" type="boolean" default="false">
        <cfargument name="staff" type="boolean" default="false">
        <cfargument name="faculty" type="boolean" default="false">
        <cfargument name="verifyPerson" type="boolean" default="true">

        <cfset var apiResponse = getPeople(false, arguments.student, arguments.staff, arguments.faculty)>
        <cfset var apiPeople = apiResponse.data>
        <cfset var xmlPeople = getPeopleFromXml(returnJson=false, student=arguments.student, staff=arguments.staff, faculty=arguments.faculty)>
        <cfset var notInApi = arrayNew(1)>
        <cfset var apiEmails = arrayNew(1)>
        
        <cfoutput><p><strong>getXmlPeopleNotInApi - API Authentication Status:</strong> #yesNoFormat(apiResponse.authenticated)# | #apiResponse.authMessage#</p></cfoutput>
        
        <!--- Build array of API emails for comparison --->
        <cfif isArray(apiPeople)>
            <cfloop array="#apiPeople#" index="person">
                <cfif structKeyExists(person, "email") and person.email neq "">
                    <cfset arrayAppend(apiEmails, lcase(person.email))>
                </cfif>
            </cfloop>
        </cfif>
        
        <!--- Find XML records not in API --->
        <cfif isArray(xmlPeople)>
            <cfloop array="#xmlPeople#" index="person">
                <cfif structKeyExists(person, "email") and person.email neq "">
                    <cfif not arrayContains(apiEmails, lcase(person.email))>
                        <cfset arrayAppend(notInApi, person)>
                    </cfif>
                </cfif>
            </cfloop>
        </cfif>

        <!--- Verify with getPeople/getPerson fallback --->
        <cfset var verifiedNotInApi = arrayNew(1)>
        <cfloop array="#notInApi#" index="person">
            <cfset var existsInPeople = personExistsInPeople(person)>
            <cfset var existsInPerson = false>

            <cfif arguments.verifyPerson>
                <cfif structKeyExists(person, 'id') and len(trim(person.id))>
                    <cftry>
                        <cfset var pResponse = getPerson(person.id, false)>
                        <cfset var p = pResponse.data>
                        <cfif isStruct(p) AND structKeyExists(p, 'id')>
                            <cfset existsInPerson = true>
                        </cfif>
                    <cfcatch>
                    </cfcatch>
                    </cftry>
                </cfif>

                <cfif NOT existsInPerson AND structKeyExists(person,'firstname') AND structKeyExists(person,'lastname') AND structKeyExists(person,'email')>
                    <cfset var candidate = getPersonByDetails(person.firstname, person.lastname, person.email)>
                    <cfif structKeyExists(candidate, 'email')>
                        <cfset existsInPerson = true>
                    </cfif>
                </cfif>
            </cfif>

            <cfif NOT existsInPeople AND NOT existsInPerson>
                <cfset arrayAppend(verifiedNotInApi, person)>
            </cfif>
        </cfloop>

        <!--- Return JSON if requested --->
        <cfif arguments.returnJson>
            <cfreturn serializeJSON(verifiedNotInApi)>
        </cfif>

        <cfreturn verifiedNotInApi>
    </cffunction>

</cfcomponent>