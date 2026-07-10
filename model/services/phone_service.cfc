component output="false" singleton {

    public any function init() {
        variables.PhoneDAO          = createObject("component", "dao.phone_DAO").init();
        variables.phoneUtil         = createObject("java", "com.google.i18n.phonenumbers.PhoneNumberUtil").getInstance();
        variables.PhoneNumberFormat = createObject("java", "com.google.i18n.phonenumbers.PhoneNumberUtil$PhoneNumberFormat");
        return this;
    }

    public struct function getPhones( required numeric userID ) {
        return { success=true, data=variables.PhoneDAO.getPhones( userID ) };
    }

    // Parses rawInput against a region hint (e.g. "US", "GB"). regionHint is only
    // a hint — if rawInput already carries a "+" country prefix, libphonenumber
    // uses that instead. regionCode in the result is the ACTUAL derived region
    // (via getRegionCodeForNumber), which may differ from the hint.
    public struct function parseNumber( required string rawInput, string regionHint = "US" ) {
        var result = { success=false, e164="", national="", international="", regionCode=arguments.regionHint, errorMessage="" };
        var raw = trim(arguments.rawInput);

        if ( !len(raw) ) {
            result.errorMessage = "Phone number is required.";
            return result;
        }

        try {
            var parsed = variables.phoneUtil.parse(
                javaCast("string", raw),
                javaCast("string", uCase(trim(arguments.regionHint)))
            );

            if ( !variables.phoneUtil.isValidNumber(parsed) ) {
                result.errorMessage = "That doesn't look like a valid phone number for " & arguments.regionHint & ".";
                return result;
            }

            result.success       = true;
            result.e164          = variables.phoneUtil.format(parsed, variables.PhoneNumberFormat.valueOf(javaCast("string", "E164")));
            result.national      = variables.phoneUtil.format(parsed, variables.PhoneNumberFormat.valueOf(javaCast("string", "NATIONAL")));
            result.international = variables.phoneUtil.format(parsed, variables.PhoneNumberFormat.valueOf(javaCast("string", "INTERNATIONAL")));
            result.regionCode    = variables.phoneUtil.getRegionCodeForNumber(parsed);
        } catch (any e) {
            // NumberParseException is a checked Java exception loaded via this app's
            // custom jar classloader — catch(any) rather than a typed catch, which
            // isn't guaranteed to match across that classloader boundary.
            result.errorMessage = len(trim(e.message ?: "")) ? e.message : "Unable to parse phone number.";
        }

        return result;
    }

    public string function toE164( required string rawInput, string regionHint = "US" ) {
        var parsed = parseNumber(arguments.rawInput, arguments.regionHint);
        return parsed.success ? parsed.e164 : "";
    }

    public boolean function isValid( required string rawInput, string regionHint = "US" ) {
        return parseNumber(arguments.rawInput, arguments.regionHint).success;
    }

    // e164Number is expected to already be a stored "+..." value; region is
    // re-derived from its "+" prefix ("ZZ" = libphonenumber's "unknown region"
    // sentinel, valid specifically because the number is self-describing).
    // style: "NATIONAL" (default) or "INTERNATIONAL". Falls back to the input
    // unchanged if it can't be parsed (e.g. legacy/malformed data).
    public string function formatForDisplay( required string e164Number, string style = "NATIONAL" ) {
        var raw = trim(arguments.e164Number);
        if ( !len(raw) ) return raw;

        try {
            var parsed = variables.phoneUtil.parse(javaCast("string", raw), javaCast("string", "ZZ"));
            if ( !variables.phoneUtil.isValidNumber(parsed) ) return raw;
            return variables.phoneUtil.format(parsed, variables.PhoneNumberFormat.valueOf(javaCast("string", uCase(arguments.style))));
        } catch (any e) {
            return raw;
        }
    }

    // phones: array of { number, type, isPrimary, countryCode }. countryCode
    // defaults to "US" when absent/blank so callers that don't pass it (e.g.
    // bulkImport_service today) keep working under NANP rules. Returns
    // { success=true, savedCount, errors=[{index, number, message}, ...] } —
    // invalid entries are reported, not silently dropped; blank numbers are
    // silently skipped (matching prior behavior).
    public struct function replacePhones( required numeric userID, required array phones ) {
        var toSave = [];
        var errors = [];
        var idx = 0;

        for ( var ph in arguments.phones ) {
            idx++;
            var rawNumber = trim(ph.number ?: "");
            if ( !len(rawNumber) ) continue;

            var hint = len(trim(ph.countryCode ?: "")) ? trim(ph.countryCode) : "US";
            var parsed = parseNumber(rawNumber, hint);

            if ( parsed.success ) {
                arrayAppend(toSave, {
                    number      = parsed.e164,
                    type        = (ph.type ?: ""),
                    isPrimary   = (ph.isPrimary ?: false),
                    countryCode = parsed.regionCode
                });
            } else {
                arrayAppend(errors, { index=idx, number=rawNumber, message=parsed.errorMessage });
            }
        }

        variables.PhoneDAO.replacePhones( userID, toSave );
        return { success=true, savedCount=arrayLen(toSave), errors=errors };
    }

    public struct function getAllUserPhonesMap() {
        return variables.PhoneDAO.getAllPrimaryPhonesMap();
    }
}
