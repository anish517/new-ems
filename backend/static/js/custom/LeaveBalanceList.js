const fetchLeaveQuota = async (event) => {
  document.querySelector("#loader").classList.remove("d-none");
  document.querySelector("#leaveQuotaDetailContainer").classList.add("d-none");
  const leaveBalanceContainer = document.querySelector(
    "#leave-balance-container"
  );
  leaveBalanceContainer.innerHTML = "";
  const employeeId = event.target.getAttribute("data-employeeId");
  try {
    const response = await api.get(
      `/api/leave-tracker/leave-balance/${employeeId}/`
    );
    document
      .querySelector("#user-pp")
      .setAttribute("src", response.data.employee.user.profile_picture);

    document.querySelector(
      "#user-full-name"
    ).innerHTML = `${response.data.employee.user.first_name} ${response.data.employee.user.first_name}`;
    document.querySelector("#user-email").innerHTML =
      response.data.employee.official_email;

    const leaveBalance = response.data.leave_balances;

    leaveBalance.forEach((item) => {
      leaveBalanceContainer.innerHTML += `
                <tr>
                      <th>${item.leave_type.name} days</th>
                      <td>${item.quota} days</td>
                </tr>
          `;
    });
  } catch (error) {
    toastr.error("Could not fetch ", error.response.status);
    console.log(error);
  } finally {
    document.querySelector("#loader").classList.add("d-none");
    document
      .querySelector("#leaveQuotaDetailContainer")
      .classList.remove("d-none");
  }
};
