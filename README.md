# Text Analyzer on Cloud Run (Private) — Terraform + GitHub Actions

A tiny Python Flask API deployed to **Cloud Run v2** with **internal ingress** and **IAM-restricted invocation**. Built and pushed to **Artifact Registry**, provisioned via **Terraform**, and continuously deployed from **GitHub Actions** using **Workload Identity Federation**.

## API

- **POST `/analyze`**  
  Body: `{"text": "I love cloud engineering!"}`  
  Response: `{"original_text":"I love cloud engineering!","word_count":4,"character_count":23}`

## Architecture (Text Diagram)

