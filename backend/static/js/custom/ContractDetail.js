let contractId = null;

const printDiv = () => {
  var divContent = document.getElementById("contract-container").innerHTML;

  var iframe = document.createElement("iframe");
  iframe.style.position = "absolute";
  iframe.style.width = "0";
  iframe.style.height = "0";
  iframe.style.border = "none";

  document.body.appendChild(iframe);

  var iframeDoc = iframe.contentWindow.document;

  var styles = Array.from(document.styleSheets)
    .map((sheet) => {
      try {
        return Array.from(sheet.cssRules)
          .map((rule) => rule.cssText)
          .join("");
      } catch (e) {
        console.warn(`Could not access stylesheet: ${sheet.href}`, e);
        return "";
      }
    })
    .join("");

  // Add content and styles to the iframe document
  iframeDoc.open();
  iframeDoc.write(`
      <!DOCTYPE html>
      <html>
      <head>
          <title>Contract</title>
          <style>
            ${styles}
          </style>
      </head>
      <body>
          ${divContent}
      </body>
      </html>
    `);
  iframeDoc.close();

  iframe.contentWindow.print();

  iframe.contentWindow.onafterprint = () => {
    document.body.removeChild(iframe);
  };
};

const getContractId = (event) => {
  contractId = event.target.getAttribute("data-id");
};

const handleDeleteContract = async (event) => {
  if (window.location.pathname === `/employees/contracts/${contractId}/`) {
    console.log("You're on the specific path!");
  }
  event.target.innerHTML = `<div class="spinner-border spinner-border-sm" role="status">
                              <span class="visually-hidden">Loading...</span>
                            </div>`;
  event.target.setAttribute("disabled", true);
  try {
    const response = await api.delete(`/api/employees/contract/${contractId}/`);
    toastr.info("Contract deleted successfully", "Success");
    if (window.location.pathname === `/employees/contracts/${contractId}/`) {
      toastr.info("You will be redirected to contract lists page.", "Info");
      setTimeout(() => {
        window.location.replace("/employees/contracts/");
      }, 2000);
    } else {
      const row = document.querySelector(`#contract-${contractId}`);
      row.remove();
      document
        .querySelector("#contractDeleteConfirmationModalCloseBtn")
        .click();
    }
  } catch (error) {
    console.error(error);
    toastr.error(`${error}`, "Error");
  } finally {
    event.target.innerHTML = "Yes";
    event.target.removeAttribute("disabled");
  }
};
