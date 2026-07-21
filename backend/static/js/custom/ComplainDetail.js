const toggleReplyForm = () => {
  const replyContainer = document.querySelector("#reply-container");
  const replyFormContainer = document.querySelector("#reply-form-container");

  replyContainer.classList.toggle("d-none");
  replyFormContainer.classList.toggle("d-none");
};
