const fetchTransactionDetail = async (event) => {
  showTransactionModalLoader();

  const transactionId = event.target.getAttribute("data-id");

  try {
    const response = await api.get(
      `/api/salary-management/transactions/${transactionId}/`
    );
    document.querySelector("#transactionDate").innerHTML = response.data.date;
    document.querySelector(
      "#transactionBasicSalary"
    ).innerHTML = `Rs. ${response.data.salary}`;
    document.querySelector("#transactionFiscalYear").innerHTML =
      response.data.fiscal_year;
    document.querySelector(
      "#transactionNetSalary"
    ).innerHTML = `Rs. ${response.data.net_salary}`;
    document.querySelector(
      "#transactionHoliday"
    ).innerHTML = `${response.data.holidays} days`;
    document.querySelector(
      "#transactionAttendance"
    ).innerHTML = `${response.data.no_of_days_present} days`;
    document.querySelector(
      "#transactionPaidLeaves"
    ).innerHTML = `${response.data.paid_leaves} days`;
    document.querySelector(
      "#transactionDeduction"
    ).innerHTML = `Rs. ${response.data.deduction}`;
    document
      .querySelector("#transactionDetailTable")
      .classList.remove("d-none");
  } catch (error) {
    toastr.error(
      `Transaction details not found.`,
      `Error ${error.response.status}`
    );
    console.log(error);
  } finally {
    document.querySelector("#loader").classList.add("d-none");
  }
};

const showTransactionModalLoader = () => {
  document.querySelector("#transactionDetailTable").classList.add("d-none");
  document.querySelector("#loader").classList.remove("d-none");
};
