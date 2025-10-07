import { LightningElement, track, wire, api } from "lwc";
import getObjectLabel from "@salesforce/apex/AccountManagerController.getObjectLabel";
import getAccounts from "@salesforce/apex/AccountManagerController.getAccounts";
import updateAccounts from "@salesforce/apex/AccountManagerController.updateAccounts";
import getAccessibleFields from "@salesforce/apex/ObjectFieldService.getAccessibleFields";
import getPicklistValues from "@salesforce/apex/AccountManagerController.getPicklistValues";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class AccountManager extends LightningElement {
  //exposed properties
  @api objectApiName;

  //header properties
  @track headerName = "";
  @track headerIconName = "";
  @track headerIconType = "";
  @track objectLabel = "";

  // 🔍 Search & Filter
  @track searchKeyword = "";
  @track selectedField = "";
  @track selectedOperator = "";
  @track filterValue = "";

  @track picklistFieldValues = {}; // dynamic picklist values
  @track picklistOptions = [];
  @track isPicklistField = false;
  @track isDateOnlyField = false;
  @track isDateTimeField = false;

  // 📊 Data & Pagination
  @track accounts = [];
  @track draftValues = [];
  @track pageNumber = 1;
  @track pageSize = 10;
  @track totalPages = 1;
  @track columns = [];

  //Sorting
  @track sortBy;
  @track sortDirection;

  //for modelpopup
  @track isModalOpen = false;

  // for dual listbox
  @track options = [];
  @track values = [];
  @track accessibleFields = [];

  // Selected fields to display
  @track initiallyFields_for_datatable = [];

  @track userCustomizedFields = false; // set true after modal Save

  operatorOptions = [
    { label: "Equals", value: "equals" },
    { label: "Contains", value: "contains" },
    { label: "Starts With", value: "startsWith" }
  ];

  // Datatable Columns (inline picklist support)
  // columns = [
  //     { label: 'Name', fieldName: 'Name', editable: true, sortable: true },
  //     {
  //         label: 'Industry',
  //         fieldName: 'Industry',
  //         editable: true,
  //         type: 'picklistColumn',
  //         typeAttributes: { placeholder: 'Select Industry', options: { fieldName: 'industryOptions' }, sortable: true }
  //     },
  //     {
  //         label: 'Type',
  //         fieldName: 'Type',
  //         editable: true,
  //         type: 'picklistColumn',
  //         typeAttributes: { placeholder: 'Select Type', options: { fieldName: 'typeOptions' }, sortable: true }
  //     },
  //     { label: 'Phone', fieldName: 'Phone', editable: true, sortable: true }
  // ];

  // Load dynamic picklist values from Apex for the selected object
  @wire(getPicklistValues, { objectApiName: "$objectApiName" })
  wiredPicklists({ data, error }) {
    if (data) {
      this.picklistFieldValues = {};
      for (let field in data) {
        this.picklistFieldValues[field] = data[field].map((v) => ({
          label: v,
          value: v
        }));
      }
      this.loadAccounts(); // Load accounts after picklist values are ready
    } else if (error) {
      console.error(error);
    }
  }

  //get the object label for header
  @wire(getObjectLabel, { objectApiName: "$objectApiName" })
  wiredObjectLabel({ data, error }) {
    if (data) {
      this.objectLabel = data;
      this.headerName = this.objectLabel + " Manager";
      this.headerIconName = "standard:" + this.objectApiName.toLowerCase();
      this.headerIconType = "standard";
    } else if (error) {
      console.error("Error fetching object label:", error);
    }
  }

  // Load accessible fields for the object
  @wire(getAccessibleFields, { objectApiName: "$objectApiName" })
  wiredAccessibleFields({ data, error }) {
    if (data) {
      this.accessibleFields = data;
      //console.log('Accessible Fields:', JSON.stringify(this.accessibleFields));

      // Auto-pick 4 defaults only if user hasn’t customized yet
      if (!this.userCustomizedFields) {
        this.initiallyFields_for_datatable = this.pickDefaultFields(
          this.accessibleFields,
          4
        );
        this.values = [...this.initiallyFields_for_datatable];
      }
      console.log(
        "Initial Fields:",
        JSON.stringify(this.initiallyFields_for_datatable)
      );

      // Build initial columns based on accessible fields and selected fields
      this.columns = this.buildColumns(this.accessibleFields);
      this.loadAccounts(); // Initial load of accounts
      // Convert accessibleFields into options for dualbox list
      this.options = data.map((field) => ({
        label: field.label, // e.g. "Account Name"
        value: field.apiName // e.g. "Name"
      }));

      this.values = [...this.initiallyFields_for_datatable];

      // Set fieldOptions for filter dropdown dropdown filter

      let fieldOptions = this.initiallyFields_for_datatable
        .map((fieldApiName) => {
          // Find the field in array A by apiName
          let fieldDef = this.accessibleFields.find(
            (f) => f.apiName === fieldApiName
          );
          if (fieldDef) {
            return { label: fieldDef.label, value: fieldDef.apiName };
          }
          return null;
        })
        .filter((item) => item !== null);
      this.fieldOptions = fieldOptions;
    } else if (error) {
      console.error("Error fetching accessible fields:", error);
    }
  }

  connectedCallback() {}

  // Load accounts and attach picklist options per row
  loadAccounts() {
    const params = {
      objectApiName: this.objectApiName,
      searchKeyword: this.searchKeyword,
      field: this.selectedField,
      operator: this.selectedOperator,
      value: this.filterValue,
      pageNumber: this.pageNumber,
      pageSize: this.pageSize,
      sortBy: this.sortBy,
      sortDirection: this.sortDirection,
      selectedFields: this.initiallyFields_for_datatable
    };
    console.log("Params for getAccounts:", JSON.stringify(params));

    getAccounts({ params })
      .then((result) => {
        // Use the correct key based on your Apex return
        const key = "records";
        // Attach dynamic picklist options for any picklist fields present in accessibleFields
        this.accounts = result[key].map((acc) => {
          let enriched = { ...acc };
          if (Array.isArray(this.accessibleFields)) {
            this.accessibleFields.forEach((field) => {
              if (
                field &&
                (field.type === "PICKLIST" || field.type === "Multipicklist")
              ) {
                let optionKey =
                  field.apiName.charAt(0).toLowerCase() +
                  field.apiName.slice(1) +
                  "Options";
                //const optionsKey = `${field.apiName}Options`;
                enriched[optionKey] =
                  this.picklistFieldValues[field.apiName] || [];
              }
            });
          }
          return enriched;
        });
        this.totalPages = Math.ceil(result.totalCount / this.pageSize);
      })
      .catch((error) => {
        this.showToast(
          "Error loading records",
          error.body?.message || error.message,
          "error"
        );
        console.error(error);
      });
  }

  // 🔍 Handlers
  handleSearchChange(event) {
    this.searchKeyword = event.target.value;
    this.pageNumber = 1; // reset to first page
    this.loadAccounts();
  }

  handleSort(event) {
    this.sortBy = event.detail.fieldName;
    this.sortDirection = event.detail.sortDirection;
    this.loadAccounts();
  }

  handleFieldChange(event) {
    this.selectedField = event.target.value;
    let fieldDef = this.accessibleFields.find(
      (f) => f.apiName === this.selectedField
    );

    // Reset UI toggles
    this.isPicklistField = false;
    this.isDateOnlyField = false;
    this.isDateTimeField = false;
    this.picklistOptions = [];
    this.filterValue = "";

    if (fieldDef && fieldDef.type === "DATE") {
      this.isDateOnlyField = true;
    } else if (fieldDef && fieldDef.type === "DATETIME") {
      this.isDateTimeField = true;
    } else if (this.picklistFieldValues[this.selectedField]) {
      this.isPicklistField = true;
      this.picklistOptions = this.picklistFieldValues[this.selectedField];
    }
  }

  handleOperatorChange(event) {
    this.selectedOperator = event.target.value;
  }
  handleValueChange(event) {
    this.filterValue = event.target.value;
  }

  applyFilter() {
    this.pageNumber = 1; // reset to first page
    this.loadAccounts();
  }

  // 📝 Save Updated Records (including picklist)
  handleSave(event) {
    const updatedFields = event.detail.draftValues;

    updateAccounts({ sObjList: updatedFields })
      .then(() => {
        this.showToast("Success", "Records updated successfully", "success");
        this.draftValues = [];
        this.loadAccounts();
      })
      .catch((error) => {
        this.showToast(
          "Error updating records",
          error.body?.message || error.message,
          "error"
        );
      });
  }

  // ⏮️ Pagination
  prevPage() {
    if (this.pageNumber > 1) {
      this.pageNumber--;
      this.loadAccounts();
    }
  }
  nextPage() {
    if (this.pageNumber < this.totalPages) {
      this.pageNumber++;
      this.loadAccounts();
    }
  }
  get isFirstPage() {
    return this.pageNumber === 1;
  }
  get isLastPage() {
    return this.pageNumber === this.totalPages;
  }

  showModelPopup() {
    this.isModalOpen = true;
  }

  closeModal() {
    this.isModalOpen = false;
  }

  buildColumns(fieldMetadata) {
    let cols = [];
    fieldMetadata.forEach((field) => {
      if (!this.initiallyFields_for_datatable.includes(field.apiName)) return;

      const normType = this.normalizeType(field.type);
      let col = {
        label: field.label,
        fieldName: field.apiName,
        sortable: true,
        editable: field.isUpdateable
      };

      // Handle standard datatable types first
      if (normType === "DATE") {
        // Use date-local for local-only rendering (no timezone conversion)
        col.type = "date-local";
        col.typeAttributes = {
          year: "numeric",
          month: "2-digit",
          day: "2-digit"
        };
      } else if (normType === "DATETIME") {
        // Datetime renders via 'date' with time attributes
        col.type = "date";
        col.typeAttributes = {
          year: "numeric",
          month: "2-digit",
          day: "2-digit",
          hour: "2-digit",
          minute: "2-digit",
          second: "2-digit",
          hour12: true
        };
      } else if (normType === "CURRENCY") {
        col.type = "currency";
        col.typeAttributes = this.getCurrencyTypeAttributes(field);
      } else if (normType === "PERCENT") {
        col.type = "percent";
        col.typeAttributes = { maximumFractionDigits: 2 };
      } else if (normType === "NUMBER") {
        col.type = "number";
        col.typeAttributes = {
          minimumIntegerDigits: 1,
          maximumFractionDigits: 2
        };
      } else if (normType === "BOOLEAN") {
        col.type = "boolean";
        // editable respected from field.isUpdateable for inline editing
      } else if (normType === "PHONE") {
        col.type = "phone";
      } else if (normType === "URL") {
        col.type = "url";
        col.typeAttributes = this.getUrlTypeAttributes(field);
      } else if (normType === "LOCATION") {
        // Datatable supports 'location' to format latitude/longitude
        col.type = "location";
        // Optionally: { latitude: { fieldName: 'Latitude__c' }, longitude: { fieldName: 'Longitude__c' } }
        // If using a single geolocation compound, the base component formats it automatically.
      } else if (normType === "PICKLIST") {
        // Custom type for inline picklist
        const optionKey =
          field.apiName.charAt(0).toLowerCase() +
          field.apiName.slice(1) +
          "Options";
        col.type = "picklistColumn";
        col.typeAttributes = {
          placeholder: `Select ${field.label}`,
          options: { fieldName: optionKey }
        };
      } else {
        // Default
        col.type = "text";
      }

      cols.push(col);
    });
    return cols;
  }

  normalizeType(t) {
    if (!t) return "TEXT";
    const up = String(t).toUpperCase();
    // Map common aliases from describe to datatable
    if (up === "STRING" || up === "TEXT" || up === "ID" || up === "REFERENCE")
      return "TEXT";
    if (up === "EMAIL") return "TEXT"; // no native email type; use url if desired
    if (up === "URL") return "URL";
    if (up === "PHONE") return "PHONE";
    if (up === "BOOLEAN") return "BOOLEAN";
    if (up === "CURRENCY") return "CURRENCY";
    if (up === "PERCENT") return "PERCENT";
    if (
      up === "DOUBLE" ||
      up === "INTEGER" ||
      up === "LONG" ||
      up === "DECIMAL"
    )
      return "NUMBER";
    if (up === "DATE") return "DATE";
    if (up === "DATETIME") return "DATETIME";
    if (up === "LOCATION" || up === "GEOLOCATION") return "LOCATION";
    if (up === "PICKLIST" || up === "MULTIPICKLIST") return "PICKLIST";
    return "TEXT";
  }

  // Optionally derive a currency code per row or org default; fallback to org default like 'USD'
  getCurrencyTypeAttributes(field) {
    return {
      currencyCode: "USD",
      maximumFractionDigits: 2
    };
  }

  // For url, optionally display another field as the label if present in selected fields
  getUrlTypeAttributes(field) {
    // Try to find a companion label field e.g., 'Name'
    const nameField = this.initiallyFields_for_datatable.includes("Name")
      ? "Name"
      : null;
    return nameField
      ? { label: { fieldName: nameField }, target: "_blank" }
      : { target: "_blank" };
  }

  handleDualListboxChange(event) {
    this.values = event.detail.value;
  }

  saveModal() {
    // Update selected fields and columns
    this.initiallyFields_for_datatable = [...this.values];
    this.columns = [];
    this.columns = this.buildColumns(this.accessibleFields);
    this.loadAccounts(); // Reload accounts to reflect new fields
    // Set fieldOptions for filter dropdown dropdown filter

    let fieldOptions = this.initiallyFields_for_datatable
      .map((fieldApiName) => {
        // Find the field in array A by apiName
        let fieldDef = this.accessibleFields.find(
          (f) => f.apiName === fieldApiName
        );
        if (fieldDef) {
          return { label: fieldDef.label, value: fieldDef.apiName };
        }
        return null;
      })
      .filter((item) => item !== null);
    this.fieldOptions = fieldOptions;

    this.isModalOpen = false;
  }

  clearFilters() {
    // Reset filter inputs
    this.searchKeyword = "";
    this.selectedField = "";
    this.selectedOperator = "";
    this.filterValue = "";

    // Reset filter UI toggles
    this.isPicklistField = false;
    this.isDateField = false;
    this.picklistOptions = [];

    // Reset grid state
    this.pageNumber = 1;
    this.sortBy = undefined;
    this.sortDirection = undefined;

    // Clear drafts and table errors if used
    this.draftValues = [];
    this.tableErrors = { rows: {}, table: {} };

    // Reload data
    this.loadAccounts();
  }

  // Generic score to prioritize human-friendly columns; no object-specific names
  scoreField(f) {
    let s = 0;
    if (f.isNameField) s += 100; // true "name" field, if any
    if (f.isExternalId) s += 20; // identifiers are useful
    if (["STRING", "PICKLIST", "PHONE", "EMAIL", "URL"].includes(f.type))
      s += 12;
    if (["DOUBLE", "CURRENCY", "INTEGER"].includes(f.type)) s += 8;
    if (["DATE", "DATETIME"].includes(f.type)) s += 6;
    if (["TEXTAREA", "LONGTEXTAREA", "RICH_TEXT_AREA"].includes(f.type)) s -= 8;
    if (f.apiName === "Id") s -= 4; // readable but not ideal as first column
    if (f.isAccessible === false) s -= 100; // exclude unreadable
    return s;
  }

  // Pure generic picker: returns up to count fields from accessibleFields
  pickDefaultFields(accessibleFields, count = 4) {
    const candidates = (accessibleFields || [])
      .filter((f) => f && f.apiName && f.isAccessible !== false)
      .filter((f) => !["BASE64", "ADDRESS", "LOCATION"].includes(f.type))
      .sort((a, b) => this.scoreField(b) - this.scoreField(a));

    const picked = [];
    for (const f of candidates) {
      if (!picked.includes(f.apiName)) picked.push(f.apiName);
      if (picked.length >= count) break;
    }
    // Fallback: if describe is sparse, just take first few apiNames present
    return picked.length
      ? picked
      : (accessibleFields || []).slice(0, count).map((f) => f.apiName);
  }

  // Toast Utility
  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
