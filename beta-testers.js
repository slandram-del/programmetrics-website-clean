(() => {
  "use strict";

  document.querySelectorAll(".reveal").forEach((element) => element.classList.add("visible"));

  const form = document.querySelector("#beta-application-form");
  const errorMessage = document.querySelector("#beta-form-error");
  const successMessage = document.querySelector("#beta-form-success");
  const submitButton = form?.querySelector('button[type="submit"]');

  if (!form || !errorMessage || !successMessage || !submitButton) return;

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    errorMessage.hidden = true;
    successMessage.hidden = true;

    if (!form.reportValidity()) return;

    const selectedFeatures = Array.from(form.querySelectorAll('input[name="features"]:checked'));
    if (selectedFeatures.length === 0) {
      errorMessage.textContent = "Please select at least one feature you are interested in testing.";
      errorMessage.hidden = false;
      form.querySelector('input[name="features"]').focus();
      return;
    }

    submitButton.disabled = true;
    submitButton.textContent = "Submitting…";

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
      errorMessage.textContent = "We could not submit your application. Please try again. If the problem continues, contact hello@programmetrics.io without including any data files or sensitive information.";
      errorMessage.hidden = false;
      errorMessage.focus();
    } finally {
      submitButton.disabled = false;
      submitButton.textContent = "Apply for Beta Access";
    }
  });
})();
