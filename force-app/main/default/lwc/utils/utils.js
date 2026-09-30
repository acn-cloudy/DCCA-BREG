function capitalizeFirstLetter(val) {
    return String(val).charAt(0).toUpperCase() + String(val).slice(1);
}

function abbreviate(str, max, suffix = "...") {
    if (
        (str = str
            .replace(/^\s+|\s+$/g, "")
            .replace(/[\r\n]*\s*[\r\n]+/g, " ")
            .replace(/[ \t]+/g, " ")).length <= max
    ) {
        return str;
    }
    let abbr = "",
        strParts = str.split(" "),
        maxLen = max - suffix.length;
    for (let len = strParts.length, i = 0; i < len; i++) {
        if ((abbr + strParts[i]).length < maxLen) {
            abbr += strParts[i] + " ";
        } else {
            break;
        }
    }
    return abbr.replace(/[ ]$/g, "") + suffix;
}

/**
 * Adds a unique key to each item in the array
 * @param {Array} items - Array of items (objects)
 * @param {string} [baseKey='item'] - Base part of the key (optional)
 * @returns {Array} New array with an added `key` field
 */
function addUniqueKeys(items, baseKey = "item") {
    return items.map((item, index) => {
        return {
            ...item,
            uniqueKey: item.uniqueKey || `${baseKey}-${index}-${Date.now()}-${Math.random().toString(36).substr(2, 5)}`
        };
    });
}

/**
 * Converts a number or string to currency format: $10,000.00
 * @param {number|string} value
 * @returns {string}
 */
function formatCurrency(value) {
    if (value == null || value === "") return "$0.00";
    let str = String(value).trim();
    // Handle negative in parentheses: ($12345.6)
    let isNegative = false;
    if (/^\(.*\)$/.test(str)) {
        isNegative = true;
        str = str.replace(/[()]/g, "");
    }
    // Remove all $ and commas
    str = str.replace(/\$/g, "").replace(/,/g, "");
    // Remove currency words (USD, etc.)
    str = str.replace(/usd|dollars?/gi, "");
    // Remove all non-numeric except . and -
    str = str.replace(/[^0-9.-]/g, "");
    let num = Number(str);
    if (isNaN(num)) return "$0.00";
    if (isNegative || /^-/.test(str)) num = -Math.abs(num);
    return num.toLocaleString("en-US", {
        style: "currency",
        currency: "USD",
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
    });
}

/**
 * Performs a deep merge of objects and returns new object. Does not modify
 * objects (immutable) and merges arrays via concatenation.
 *
 * @param {...object} objects - Objects to merge
 * @returns {object} New object with merged key/values
 */
function deepMergeObjects(...objects) {
    const isObject = (obj) => obj && typeof obj === "object";

    return objects.reduce((prev, obj) => {
        Object.keys(obj).forEach((key) => {
            const pVal = prev[key];
            const oVal = obj[key];

            if (Array.isArray(pVal) && Array.isArray(oVal)) {
                prev[key] = pVal.concat(...oVal);
            } else if (isObject(pVal) && isObject(oVal)) {
                prev[key] = deepMergeObjects(pVal, oVal);
            } else {
                prev[key] = oVal;
            }
        });

        return prev;
    }, {});
}

function getQuarterEndDate(inputDate) {
    const date = new Date(inputDate);
    if (isNaN(date)) {
        return "";
    }
    const year = date.getFullYear();
    const month = date.getMonth();
    let result = "";

    if (month <= 2) {
        result = `03/31/${year}`;
    } else if (month <= 5) {
        result = `06/30/${year}`;
    } else if (month <= 8) {
        result = `09/30/${year}`;
    } else {
        result = `12/31/${year}`;
    }

    return result;
}

function getNextQuarterStartDate(inputDate) {
    const date = new Date(inputDate);
    if (isNaN(date)) {
        return "";
    }
    const year = date.getFullYear();
    const month = date.getMonth();
    let result = "";

    if (month <= 2) {
        result = `04/01/${year}`;
    } else if (month <= 5) {
        result = `07/01/${year}`;
    } else if (month <= 8) {
        result = `10/01/${year}`;
    } else {
        result = `01/01/${year + 1}`;
    }

    return result;
}

/**
 * Navigates to a new page with optional URL parameters
 * @param {string} pagePath - The page path to navigate to
 * @param {object} paramsObj - Object with camelCase keys that will be converted to dash-separated URL parameters
 * @example
 * // navigateToPage('dashboard', { fileNumber: '123', section: 'overview' })
 * // Navigates to: /dashboard?file-number=123&section=overview
 */
function navigateToPage(pagePath, paramsObj) {
    let url = pagePath;
    const urlParams = preparePageUrlParams(paramsObj);
    if (urlParams && urlParams.size > 0) {
        url += "?" + urlParams.toString();
    }
    window.location.href = url;
}

/**
 * Extracts URL parameters from the current page URL and converts dash-separated parameter names to camelCase
 * @returns {object} Object with camelCase keys containing URL parameter values
 * @example
 * // URL: ?file-number=123&form-config-id=abc&section=overview
 * // Returns: { fileNumber: '123', formConfigId: 'abc', section: 'overview' }
 */
function getPageParamsFromUrl() {
    try {
        const urlParams = new URLSearchParams(window.location.search);
        const result = {};

        // Helper function to convert dash-separated to camelCase
        const dashToCamel = (str) => {
            return str.replace(/-([a-z])/g, (match, letter) => letter.toUpperCase());
        };

        // Iterate through all URL parameters using URLSearchParams.entries()
        for (const [key, value] of urlParams.entries()) {
            if (value !== null && value !== "") {
                result[dashToCamel(key)] = value;
            }
        }

        return result;
    } catch (error) {
        console.error("Error parsing URL parameters:", error);
        return {};
    }
}

/**
 * Get page parameters from Lightning Navigation state
 */
function getStateParamsFromUrl(pageReference) {
    const stateParams = {};
    if (pageReference && pageReference.state) {
        // Extract custom state parameters (prefixed with c__)
        Object.keys(pageReference.state).forEach((key) => {
            if (key.startsWith("c__")) {
                // Convert c__formConfigId to formConfigId
                const paramName = key.substring(3); // Remove 'c__' prefix
                const camelCaseName = paramName.charAt(0).toLowerCase() + paramName.slice(1);
                stateParams[camelCaseName] = pageReference.state[key];
            }
        });
    }

    return stateParams;
}

/**
 * Sets URL parameters in the current page URL
 * @param {object} paramsObj - Object with camelCase keys and their values to set as URL parameters
 * @example
 * // setPageUrlParams({ fileNumber: '123', formConfigId: 'abc', section: 'overview' })
 * // Sets URL to: ?file-number=123&form-config-id=abc&section=overview
 */
function setPageUrlParams(paramsObj) {
    const url = new URL(window.location.href);
    const urlParams = preparePageUrlParams(paramsObj);

    window.history.pushState({}, "", `${url.pathname}?${urlParams.toString()}`);
    window.dispatchEvent(new PopStateEvent("popstate"));
}

/**
 * Prepares URLSearchParams object by converting camelCase object keys to dash-separated URL parameters
 * @param {object} paramsObj - Object with camelCase keys and their values to convert to URL parameters
 * @returns {URLSearchParams} URLSearchParams object with dash-separated parameter names
 * @example
 * // preparePageUrlParams({ fileNumber: '123', formConfigId: 'abc' })
 * // Returns URLSearchParams with: file-number=123&form-config-id=abc
 */
function preparePageUrlParams(paramsObj) {
    try {
        const urlParams = new URLSearchParams();

        // Return empty URLSearchParams if paramsObj is null, undefined, or not an object
        if (!paramsObj || typeof paramsObj !== "object") {
            return urlParams;
        }

        // Helper function to convert camelCase to dash-separated
        const camelToDash = (str) => {
            return str.replace(/([A-Z])/g, "-$1").toLowerCase();
        };

        // Iterate through the provided params
        Object.entries(paramsObj).forEach(([key, value]) => {
            if (value !== null && value !== undefined && value !== "") {
                console.log(`Setting URL parameter: ${camelToDash(key)} = ${value}`);
                urlParams.set(camelToDash(key), value);
            }
        });

        return urlParams;
    } catch (error) {
        console.error("Error preparing URL parameters:", error);
        return {};
    }
}

function createDownloadLink(base64String, description, fileType) {
    // Convert base64 to blob and trigger download
    const byteCharacters = atob(base64String);
    const byteNumbers = new Array(byteCharacters.length);
    for (let i = 0; i < byteCharacters.length; i++) {
        byteNumbers[i] = byteCharacters.charCodeAt(i);
    }
    const byteArray = new Uint8Array(byteNumbers);
    let blobType;
    if (fileType === "pdf") {
        blobType = "application/pdf";
    } else if (fileType === "csv") {
        blobType = "text/plain";
    }
    const blob = new Blob([byteArray], { type: blobType });

    // Create download link
    const url = window.URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `${description}.${fileType}`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    window.URL.revokeObjectURL(url);
}

/**
 * Opens a base64-encoded PDF in a new tab so the browser's native PDF viewer
 * (and its print control) is shown, instead of triggering a file download.
 * @param {string} base64String - Base64-encoded PDF content
 * @param {Window} targetWindow - A window handle opened synchronously on the user gesture
 *   (e.g. via window.open("", "_blank")) before any await, to avoid popup blockers.
 */
function openPdfInNewTab(base64String, targetWindow) {
    const byteCharacters = atob(base64String);
    const byteNumbers = new Array(byteCharacters.length);
    for (let i = 0; i < byteCharacters.length; i++) {
        byteNumbers[i] = byteCharacters.charCodeAt(i);
    }
    const byteArray = new Uint8Array(byteNumbers);
    const blob = new Blob([byteArray], { type: "application/pdf" });
    const url = window.URL.createObjectURL(blob);

    if (targetWindow) {
        targetWindow.location = url;
    } else {
        window.open(url, "_blank");
    }
}

/**
 * Safely navigates through nested object properties using a dot-separated path
 * @param {object} obj - The object to navigate through
 * @param {string} path - Dot-separated path to the desired property (e.g., "Account.Name" or "breg_Account_Affiliation__c.breg_Contact__r.Email")
 * @returns {*} The value at the specified path, or undefined if the path doesn't exist
 * @example
 * // getFieldValueFromPath({ Account: { Name: "Acme Corp" } }, "Account.Name")
 * // Returns: "Acme Corp"
 * // getFieldValueFromPath({ breg_Account_Affiliation__c: { breg_Contact__r: { Email: "test@example.com" } } }, "breg_Account_Affiliation__c.breg_Contact__r.Email")
 * // Returns: "test@example.com"
 */
function getFieldValueFromPath(obj, path) {
    const keys = path.split(".");
    let current = obj;

    for (const key of keys) {
        if (current && typeof current === "object" && key in current) {
            current = current[key];
        } else {
            return undefined;
        }
    }

    return current;
}

/**
 * Removes unique symbol suffix from target field if present
 * @param {string} targetField - The target field name that may contain a unique symbol
 * @param {string} uniqueSymbol - The unique symbol to look for (default: ' - ')
 * @returns {string} Cleaned target field name
 */
function cleanTargetField(targetField, uniqueSymbol = " - ") {
    if (targetField.includes(uniqueSymbol)) {
        return targetField.substring(0, targetField.indexOf(uniqueSymbol));
    }
    return targetField;
}

function isNotCraMemberType(affiliation) {
    console.log("Checking if affiliation is not CRA member type:", JSON.stringify(affiliation));
    console.log(affiliation?.breg_Account__r?.breg_BRIM_CRA_FL__c);
    const isCraByAffiliationType = (affiliation?.breg_Type__c ?? affiliation?.memberType) === "CRA";
    const isCraByAccountFlag =
        affiliation?.breg_Account__r?.breg_BRIM_CRA_FL__c === true;
        console.log("isNotCraMemberType: " + (!isCraByAffiliationType && !isCraByAccountFlag));
    return !isCraByAffiliationType && !isCraByAccountFlag;
}

/**
 * Sets form data based on form configuration and record
 * @param {object} params - Parameters object
 * @param {object} params.formConfiguration - Form configuration object
 * @param {object} params.record - Record data to populate form
 * @param {boolean} params.useSourceFieldsMapping - Whether to use source fields mapping
 * @param {boolean} params.shouldSetRecordId - Whether to set record ID in form data
 * @returns {object|null} Form data object or null if required params are missing
 * @example
 * // const formData = setFormData({
 * //     formConfiguration: this.formConfiguration,
 * //     record: this.accountData,
 * //     useSourceFieldsMapping: true,
 * //     shouldSetRecordId: this.shouldSetRecordId
 * // });
 */
function setFormData({ formConfiguration, record, useSourceFieldsMapping, shouldSetRecordId }) {
    const UNIQUE_SYMBOL_FOR_TARGET_FIELD = " - ";
    const MEMBER_ROLE_FIELD = "breg_Account_Affiliation__c.breg_Role__c";
    const MEMBER_ID_FIELD = "breg_Account_Affiliation__c.Id";
    const currentFormCode = formConfiguration?.formCode;

    if (!formConfiguration || !record) {
        console.warn("** formConfiguration or record is not set, skipping setFormData");
        return null;
    }

    const formData = {};
    const members = [];
    const stocksAnnuals = [];
    const stocksPaidIn = [];
    const stocksAuthorized = [];
    const affiliations = record.Account_Affiliations__r || record.breg_Account_Affiliations_Entity__r || record.breg_Account_Affiliations__r || [];

    function upsertMember(member, memberRole, shouldMergeByRole = false) {
        if (!shouldMergeByRole || !memberRole) {
            members.push(member);
            return;
        }

        const existingIndex = members.findIndex((existingMember) => existingMember?.[MEMBER_ROLE_FIELD] === memberRole);
        if (existingIndex === -1) {
            members.push(member);
            return;
        }

        members[existingIndex] = { ...members[existingIndex], ...member };
    }

    // Set initial values for formData
    if (formConfiguration.elements) {
        formConfiguration.elements.forEach((element) => {
            const fieldMappingJson = useSourceFieldsMapping ? element.sourceFieldsMapping : element.targetFieldsMapping;
            if (fieldMappingJson) {
                try {
                    const fieldMapping = JSON.parse(fieldMappingJson);
                    if (element.name === "Members" || element.name === "Members Change") {
                        const isMembersChange = element.name === "Members Change";
                        const skipSourceAffiliationKeys = isMembersChange && useSourceFieldsMapping;
                        const targetDefaultValues = element?.targetDefaultValues ? JSON.parse(element.targetDefaultValues) : {};
                        const componentSettings = element?.componentSettings ? JSON.parse(element?.componentSettings) : {};
                        const memberRole = targetDefaultValues[MEMBER_ROLE_FIELD] || componentSettings?.memberRole;
                        // Create reverse mapping for getting inputField when SourceFieldsMapping is used
                        const reverseFieldsMapping = {};
                        if (useSourceFieldsMapping) {
                            const targetFieldsMapping = JSON.parse(element?.targetFieldsMapping);
                            for (const [inputField, sfField] of Object.entries(targetFieldsMapping)) {
                                reverseFieldsMapping[sfField] = inputField;
                            }
                        }
                        // console.log("Affiliations found:", affiliations.length);
                        // console.log("Member role to match:", memberRole);
                        // console.log("Field mapping:", fieldMapping);
                        // console.log("Reverse field mapping:", reverseFieldsMapping);

                        // Iterate through affiliations and create member entries
                        if (componentSettings?.prefillFromEntity && useSourceFieldsMapping) {
                            console.log("Prefilling members from entity affiliations");
                            const member = {};
                            for (let [targetField, sourceField] of Object.entries(fieldMapping)) {
                                const dotIndex = sourceField.indexOf(".");
                                let fieldPath = dotIndex !== -1 ? sourceField.substring(dotIndex + 1) : sourceField;
                                const formDataField = useSourceFieldsMapping ? targetField : sourceField;
                                member[formDataField] = getFieldValueFromPath(record, fieldPath);
                                member[MEMBER_ROLE_FIELD] = memberRole;
                            }
                            upsertMember(member, memberRole, isMembersChange);

                            console.log("Form data after prefill from entity:", JSON.stringify(formData));
                        }
                        affiliations.forEach((affiliation) => {
                            if (
                                affiliation?.breg_Role__c &&
                                memberRole &&
                                affiliation.breg_Role__c === memberRole &&
                                (currentFormCode !== "X-8" || isNotCraMemberType(affiliation)) &&
                                (affiliation.breg_End_Date__c === null || affiliation.breg_End_Date__c === undefined)
                            ) {
                                const member = {};
                                member[MEMBER_ROLE_FIELD] = memberRole;
                                if (shouldSetRecordId && !skipSourceAffiliationKeys) {
                                    member[MEMBER_ID_FIELD] = affiliation.Id;
                                }
                                for (let [targetField, sourceField] of Object.entries(fieldMapping)) {
                                    // Remove unique symbol from targetField if present. It's used to differentiate multiple mappings to the same field
                                    targetField = cleanTargetField(targetField, UNIQUE_SYMBOL_FOR_TARGET_FIELD);

                                    let fieldPath;
                                    if (sourceField.startsWith("Contact.")) {
                                        fieldPath = sourceField.replace("Contact.", "breg_Contact__r.");
                                    } else if (sourceField.startsWith("Account.")) {
                                        fieldPath = sourceField.replace("Account.", "breg_Account__r.");
                                    } else if (sourceField.startsWith("breg_Account_Affiliation__c.")) {
                                        fieldPath = sourceField.replace("breg_Account_Affiliation__c.", "");
                                    } else {
                                        continue;
                                    }
                                    const value = getFieldValueFromPath(affiliation, fieldPath);

                                    const inputField = useSourceFieldsMapping ? reverseFieldsMapping[targetField] : targetField;
                                    // console.log("Getting value for fieldPath:", fieldPath);
                                    // console.log("Field value:", value);
                                    // console.log("Input Field:", inputField);
                                    const formDataField = useSourceFieldsMapping ? targetField : sourceField;

                                    if (skipSourceAffiliationKeys && (inputField === "affiliationId" || formDataField === MEMBER_ID_FIELD)) {
                                        continue;
                                    }

                                    // Do not overwrite existing value
                                    if (member[formDataField] !== undefined) continue;

                                    member[inputField] = value;
                                    member[formDataField] = value;
                                }

                                // Set memberName based on firstName/lastName or entityName
                                if (member?.memberType === "Entity") {
                                    member.memberName = member.entityName || "";
                                } else {
                                    member.memberName = `${member?.firstName || ""} ${member?.lastName || ""}`;
                                }

                                // Populate Contact and Account lookups
                                if (!skipSourceAffiliationKeys) {
                                    if (!member["breg_Account_Affiliation__c.breg_Contact__c"]) {
                                        member["breg_Account_Affiliation__c.breg_Contact__c"] = affiliation?.breg_Contact__c;
                                    }
                                    if (!member["breg_Account_Affiliation__c.breg_Account__c"]) {
                                        member["breg_Account_Affiliation__c.breg_Account__c"] = affiliation?.breg_Account__c;
                                    }
                                }

                                upsertMember(member, memberRole, isMembersChange);
                            }
                        });
                    } else if (element.name === "Stocks Annuals" || element.name === "Stocks Paid In" || element.name === "Stocks Authorized") {
                        // Handle Stocks Annuals element - map stock records to formData.stocks
                        const stockRecords = record.Stocks__r || [];
                        console.log("Stock records:", JSON.stringify(stockRecords));

                        // Create reverse mapping for getting inputField when SourceFieldsMapping is used
                        const reverseFieldsMapping = {};
                        if (useSourceFieldsMapping) {
                            const targetFieldsMapping = JSON.parse(element?.targetFieldsMapping);
                            for (const [inputField, sfField] of Object.entries(targetFieldsMapping)) {
                                reverseFieldsMapping[sfField] = inputField;
                            }
                        }

                        stockRecords.forEach((stockRecord) => {
                            const stock = {};
                            if (shouldSetRecordId) {
                                stock["breg_Stock__c.Id"] = stockRecord.Id;
                            }

                            for (let [targetField, sourceField] of Object.entries(fieldMapping)) {
                                // Remove unique symbol from targetField if present
                                targetField = cleanTargetField(targetField, UNIQUE_SYMBOL_FOR_TARGET_FIELD);

                                let fieldPath;
                                if (sourceField.startsWith("breg_Stock__c.")) {
                                    fieldPath = sourceField.replace("breg_Stock__c.", "");
                                } else {
                                    continue;
                                }

                                const value = getFieldValueFromPath(stockRecord, fieldPath);
                                const inputField = useSourceFieldsMapping ? reverseFieldsMapping[targetField] : targetField;
                                const formDataField = useSourceFieldsMapping ? targetField : sourceField;

                                // Do not overwrite existing value
                                if (stock[formDataField] !== undefined) continue;

                                stock[inputField] = value;
                                stock[formDataField] = value;
                            }

                            console.log("Stock to be added");
                            if (element.name === "Stocks Annuals") {
                                console.log("Stock to be added to stocksAnnuals:", JSON.stringify(stock));
                                stocksAnnuals.push(stock);
                            } else if (element.name === "Stocks Paid In" && stockRecord.breg_Stock_Class__c === "Preferred") {
                                console.log("Stock to be added to stocksPaidIn:", JSON.stringify(stock));
                                stocksPaidIn.push(stock);
                            } else if (element.name === "Stocks Authorized" && stockRecord.breg_Stock_Class__c === "Common") {
                                console.log("Stock to be added to stocksAuthorized:", JSON.stringify(stock));
                                stocksAuthorized.push(stock);
                            }
                        });
                    } else {
                        for (let [targetField, sourceField] of Object.entries(fieldMapping)) {
                            // Remove unique symbol from targetField if present. It's used to differentiate multiple mappings to the same field
                            targetField = cleanTargetField(targetField, UNIQUE_SYMBOL_FOR_TARGET_FIELD);

                            const dotIndex = sourceField.indexOf(".");
                            let fieldPath = dotIndex !== -1 ? sourceField.substring(dotIndex + 1) : sourceField;
                            const formDataField = useSourceFieldsMapping ? targetField : sourceField;

                            /*
                             * Do not overwrite existing value
                             * It's used when multiple fields can be mapped to 1 field (E.g State and State Text)
                             * In this case, we keep the first mapped value
                             */
                            if (formData[formDataField] !== undefined) continue;

                            if (sourceField.includes("breg_Account_Affiliation__c")) {
                                /*
                                 * Mapping from affiliation[array] to the master record[singled]
                                 * Map first member with specified role or first member in array if no role specified
                                 */
                                let memberRole = JSON.parse(element?.componentSettings)?.memberRole || null;
                                const value = getFieldValueFromAffiliation(affiliations, fieldPath, memberRole, currentFormCode);
                                formData[formDataField] = value;
                            } else {
                                // Default mapping
                                formData[formDataField] = getFieldValueFromPath(record, fieldPath);
                            }
                        }
                    }
                } catch (error) {
                    console.error("Error parsing targetFieldsMapping for element:", JSON.stringify(element), JSON.stringify(error), error.message);
                }
            }
        });
    }

    formData.members = members;
    formData.stocksAnnuals = stocksAnnuals;
    formData.stocksPaidIn = stocksPaidIn;
    formData.stocksAuthorized = stocksAuthorized;
    if (shouldSetRecordId) {
        formData["Case.Id"] = record.Id;
    }

    console.log("Form data set:", JSON.stringify(formData));
    console.log("Form data set:", { ...formData });
    return formData;
}

function getFieldValueFromAffiliation(affiliations, path, memberRole, formCode) {
    let member = {};
    // find the first affiliation matching the memberRole (if specified)
    if (memberRole) {
        for (const affiliation of affiliations) {
            if (affiliation?.breg_Role__c === memberRole && (formCode !== "X-8" || isNotCraMemberType(affiliation))) {
                member = affiliation;
                break;
            }
        }
    } else {
        member = formCode === "X-8" ? affiliations.find((affiliation) => isNotCraMemberType(affiliation)) || {} : affiliations[0] || {};
    }
    return getFieldValueFromPath(member, path);
}

/**
 * Validates phone number format
 * Allows only digits and separators: +, -, (, ), spaces
 * Requires 10-15 digits (excluding separators)
 * @param {string} phoneNumber - The phone number to validate
 * @returns {object} - { isValid: boolean, errorMessage: string }
 */
function validatePhoneNumber(phoneNumber) {
    if (!phoneNumber || phoneNumber.trim() === '') {
        return { isValid: true, errorMessage: '' }; // Empty is valid (handled by required attribute)
    }

    // Check for invalid characters (only allow digits, +, -, (, ), and spaces)
    const validCharsPattern = /^[\d+()\s-]+$/;
    if (!validCharsPattern.test(phoneNumber)) {
        return {
            isValid: false,
            errorMessage: 'Phone number can only contain digits and the following separators: +, -, (, ), spaces'
        };
    }

    // Count only digits (exclude separators)
    const digitCount = phoneNumber.replace(/[^\d]/g, '').length;

    if (digitCount < 10) {
        return {
            isValid: false,
            errorMessage: 'Phone number must contain at least 10 digits'
        };
    }

    if (digitCount > 15) {
        return {
            isValid: false,
            errorMessage: 'Phone number cannot contain more than 15 digits'
        };
    }

    return { isValid: true, errorMessage: '' };
}

function formatDate(dateValue) {
    if (!dateValue) return "";
    const date = new Date(dateValue);
    return date.toLocaleDateString("en-US", {
        year: "numeric",
        month: "short",
        day: "numeric",
        timeZone: "UTC"
    });
}

export {
    getFieldValueFromPath,
    formatCurrency,
    capitalizeFirstLetter,
    abbreviate,
    addUniqueKeys,
    deepMergeObjects,
    getQuarterEndDate,
    getNextQuarterStartDate,
    navigateToPage,
    getPageParamsFromUrl,
    setPageUrlParams,
    preparePageUrlParams,
    createDownloadLink,
    openPdfInNewTab,
    setFormData,
    getStateParamsFromUrl,
    validatePhoneNumber,
    formatDate
};