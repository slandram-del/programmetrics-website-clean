(() => {
  "use strict";

  document.querySelectorAll(".reveal").forEach((element) => element.classList.add("visible"));

  const form = document.querySelector("#template-feedback-form");
  const errorMessage = document.querySelector("#template-feedback-error");
  const successMessage = document.querySelector("#template-feedback-success");
  const submitButton = form?.querySelector('button[type="submit"]');
  const emailInput = form?.querySelector('input[name="email"]');
  const followUpConsent = form?.querySelector('input[name="followUpConsent"]');

  if (!form || !errorMessage || !successMessage || !submitButton || !emailInput || !followUpConsent) return;

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    errorMessage.hidden = true;
    successMessage.hidden = true;

    if (!form.reportValidity()) return;

    if (emailInput.value.trim() && !followUpConsent.checked) {
      errorMessage.textContent = "Please confirm that ProgramMetrics may contact you about your feedback, or remove the optional email address.";
      errorMessage.hidden = false;
      followUpConsent.focus();
      return;
    }

    submitButton.disabled = true;
    submitButton.textContent = "Submitting...";

    try {
      const response = await fetch(form.action, {
        method: "POST",
        body: new FormData(form),
        headers: { Accept: "application/json" },
      });

      if (!response.ok) throw new Error("Submission failed");

      form.reset();
      successMessage.hidden = false;
      successMessage.focus();
    } catch {
      errorMessage.textContent = "We could not submit your feedback. Please try again. If the problem continues, contact hello@programmetrics.io without attaching files or including sensitive information.";
      errorMessage.hidden = false;
      errorMessage.focus();
    } finally {
      submitButton.disabled = false;
      submitButton.textContent = "Send Template Feedback";
    }
  });
})();
