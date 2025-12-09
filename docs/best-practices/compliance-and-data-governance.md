# Compliance & Data Governance Best Practices

Checklist-style guidance for handling data, privacy, and regulatory concerns around AKS and its workloads.

---

## 1. Data Classification & Inventory

- **Define a clear data classification scheme (e.g. Public, Internal, Confidential, Restricted)**  
  *Why*: Provide a common language for risk and required controls.

- **Identify and document where each class of data is stored and processed**  
  *Why*: Support impact assessments, incident response, and compliance reporting.

- **Tag resources and namespaces with data classification and ownership**  
  *Why*: Enable targeted policies, monitoring, and access controls per data sensitivity.

- **Review data flows between services and external systems**  
  *Why*: Understand where sensitive data travels and where additional controls are needed.

---

## 2. Regulatory & Policy Mapping

- **Map applicable regulations and standards (e.g. GDPR, HIPAA, PCI, ISO) to concrete controls**  
  *Why*: Ensure requirements are implemented as technical and process-level measures, not just documented.

- **Maintain a control matrix linking requirements to implementations in AKS and dependent services**  
  *Why*: Provide traceability from regulation to specific configuration, code, and processes.

- **Keep policies and standards in version control**  
  *Why*: Track changes over time and align technical baselines (security, reliability, observability) with written policies.

---

## 3. Access Control & Least Privilege

- **Use role-based access control (RBAC) for both Azure and Kubernetes with least privilege**  
  *Why*: Limit who can view, modify, or delete sensitive resources and data.

- **Separate duties between infra, platform, and application teams**  
  *Why*: Reduce risk of unilateral actions and support compliance requirements for segregation of duties.

- **Restrict direct access to production data**  
  *Why*: Ensure most developers and operators use lower environments or anonymized data for troubleshooting.

- **Use just-in-time elevation for privileged roles**  
  *Why*: Reduce the time window in which high-privilege accounts can be misused.

---

## 4. Identity, Authentication & Authorization

- **Use strong identity providers (e.g. Azure AD) with MFA and conditional access**  
  *Why*: Protect access to management planes and sensitive applications.

- **Implement fine-grained authorization in applications for sensitive operations**  
  *Why*: Enforce business rules and approvals around high-impact actions (e.g. data export, deletion).

- **Use managed identities and short-lived tokens instead of long-lived keys**  
  *Why*: Reduce key management burden and limit exposure windows if credentials are leaked.

- **Centralize and audit authentication and authorization decisions where possible**  
  *Why*: Improve visibility into who accessed what, when, and how.

---

## 5. Data Minimization & Privacy by Design

- **Collect only the data necessary for business purposes**  
  *Why*: Reduce exposure and compliance scope by avoiding unnecessary sensitive data.

- **Avoid storing sensitive data in logs, metrics, and traces**  
  *Why*: Prevent propagation of confidential or personal data into multiple systems with different retention policies.

- **Mask, anonymize, or pseudonymize data where full detail is not required**  
  *Why*: Lower risk while still enabling analytics and debugging.

- **Design APIs and schemas with privacy in mind (opt-in, explicit fields, limited defaults)**  
  *Why*: Avoid accidental over-collection or broad access to personal data.

---

## 6. Data Retention & Deletion

- **Define retention periods per data class and legal/compliance requirements**  
  *Why*: Balance legal obligations with data minimization and storage costs.

- **Implement automated retention and deletion policies for databases and storage**  
  *Why*: Ensure data is not kept longer than necessary and manual cleanup is not required.

- **Apply retention and deletion to observability data (logs, metrics, traces)**  
  *Why*: Prevent sensitive data from persisting indefinitely in monitoring systems.

- **Provide processes and tooling for data subject requests (e.g. access, rectification, erasure)**  
  *Why*: Comply with privacy regulations that grant individuals rights over their data.

---

## 7. Encryption & Key Management

- **Encrypt data at rest for all storage containing sensitive data**  
  *Why*: Protect against unauthorized access to disks and backups.

- **Use TLS for all data in transit, internal and external**  
  *Why*: Prevent eavesdropping and tampering on network traffic.

- **Use centrally managed key management systems (e.g. Azure Key Vault)**  
  *Why*: Standardize key rotation, access control, and auditing for encryption keys and secrets.

- **Rotate keys and secrets regularly and on incident**  
  *Why*: Limit the impact window if cryptographic material is compromised.

---

## 8. Audit, Logging & Evidence

- **Enable and retain audit logs for control planes and data access**  
  *Why*: Provide evidence of who did what, when, for compliance and investigations.

- **Correlate application access logs with identity and authorization decisions**  
  *Why*: Enable detailed reconstruction of access to sensitive records.

- **Protect audit logs from tampering (write-once or restricted access)**  
  *Why*: Ensure logs are trustworthy as evidence in audits and incident response.

- **Document how logs and evidence are accessed during internal and external audits**  
  *Why*: Streamline audit processes and reduce ad-hoc data gathering.

---

## 9. Backup, Restore & Legal Hold

- **Back up critical data with retention policies aligned to regulatory needs**  
  *Why*: Meet legal and business continuity requirements while avoiding over-retention.

- **Test restores regularly and document procedures**  
  *Why*: Prove that backups are usable and that RTO/RPO objectives are achievable.

- **Support legal hold processes on selected data sets**  
  *Why*: Preserve relevant data during investigations or litigation without freezing all data.

- **Ensure backups and replicas are protected at the same level as primaries**  
  *Why*: Avoid weaker controls on backup copies that could become an easier target.

---

## 10. Third-Party & Supply Chain Considerations

- **Assess compliance posture of third-party services and libraries**  
  *Why*: Dependencies inherit risk; ensure vendors meet required standards.

- **Maintain a system of record for data processors and sub-processors**  
  *Why*: Track where data goes and who is responsible for its protection.

- **Include data protection clauses and DPAs in vendor contracts**  
  *Why*: Make legal responsibilities and SLAs explicit for handling and securing data.

- **Monitor data transfers to third parties for scope creep**  
  *Why*: Prevent gradual expansion of data sharing beyond initial purposes.

---

## 11. Governance, Training & Continuous Improvement

- **Establish a data governance body or working group**  
  *Why*: Provide ownership and coordination for data-related policies and decisions.

- **Train engineers and operators on data handling and privacy requirements**  
  *Why*: Ensure day-to-day decisions align with compliance obligations.

- **Include compliance checks in architecture and design reviews**  
  *Why*: Catch potential violations early when changes are cheap.

- **Regularly review and update policies and implementations**  
  *Why*: Keep up with evolving regulations, business needs, and technical architectures.

- **Conduct periodic internal audits and readiness assessments**  
  *Why*: Identify gaps before external audits or incidents surface them.
