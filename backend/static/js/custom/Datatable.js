const initDataTables = () => {
  const tables = document.querySelectorAll(".dataTable");
  tables.forEach((table) => {
    let id = table.getAttribute("id");
    $(`#${id}`).DataTable({
      ordering: false,
      lengthMenu: [25, 50, 100],
      language: {
        paginate: {
          next: '<i class="fa fa-angle-double-right" aria-hidden="true"></i>',
          previous:
            '<i class="fa fa-angle-double-left" aria-hidden="true"></i>',
        },
      },
    });
  });
};

document.addEventListener("DOMContentLoaded", () => {
  initDataTables();
});
