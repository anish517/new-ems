const ckWordCount = document.querySelector(
  "#id_content_script-word-count > div"
);

const loader = `<div class="ms-2 spinner-border spinner-border-sm" role="status">
                  <span class="visually-hidden">Loading...</span>
                </div>`;

const fetchNetSalary = async (event) => {
  const salaryId = document.querySelector("#id_salary").value;
  const date = document.querySelector("#id_date").value;
  if (salaryId) {
    document.querySelector("#net\\ salary > label").innerHTML += loader;
    try {
      const response = await api.get(
        `/api/salary-management/net-salary/${salaryId}/?date=${date}`
      );
      document.querySelector("#id_net_salary").value = response.data.net_salary;
    } catch (error) {
      toastr.error(
        "Salary details not found.",
        `${error.response.status} Error`
      );
    } finally {
      document.querySelector("#net\\ salary > label").innerHTML = "Net salary";
    }
  }
};

document.addEventListener("DOMContentLoaded", () => {
  document.querySelector("#id_salary").addEventListener("change", (event) => {
    fetchNetSalary(event);
  });
  $(`#id_date`).nepaliDatePicker({
    onChange: function (event) {
      fetchNetSalary(event);
    },
  });
});
