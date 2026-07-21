const fetchFileDetail = (element) => {
  const fileId = element.getAttribute("data-fileId");
  api
    .get(`/organization/api/organization_file/${fileId}/`)
    .then((res) => {
      document.querySelector("#modal-file-name").textContent = res.data.title;
      document.querySelector("#modal-file-description").textContent =
        res.data.description;
      document.querySelector(
        "#modal-file-size"
      ).value = `Download (${res.data.file_size})`;
      document
        .querySelector("#modal-file-source")
        .setAttribute("href", res.data.file);
      document
        .querySelector("#modal-file-delete-btn")
        .setAttribute(
          "href",
          `/organization/organization-folder/delete-file/${res.data.id}/`
        );
    })
    .catch((err) => {
      console.log(err);
    });
};
