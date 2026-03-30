---
id: TASK-29.4
title: SP2.004 — Ansible Project Structure and Dynamic Inventory
status: To Do
assignee: []
created_date: '2026-03-30 16:42'
labels:
  - story
milestone: m-2
dependencies: []
references:
  - ansible/
  - ansible/inventory/azure_rm.yml
  - ansible/ansible.cfg
documentation:
  - doc-13
parent_task_id: TASK-29
priority: high
ordinal: 2004
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create the Ansible project structure at ansible/ with ansible.cfg, site.yml, and inventory/azure_rm.yml dynamic inventory plugin. Configure azure_rm.yml to use UAMI authentication (auth_source: msi), include the klc-rg-kafkalab-scus resource group, and create keyed_groups for component, environment, and location tags. Set compose block for ansible_host (private IP) and ansible_user (azureuser). Create group_vars/all.yml for global settings and requirements.yml for collections.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 ansible/ directory exists with ansible.cfg, site.yml, inventory/azure_rm.yml
- [ ] #2 azure_rm.yml uses azure.azcollection.azure_rm plugin with auth_source: msi
- [ ] #3 keyed_groups configured for component, environment, and location tags
- [ ] #4 compose block sets ansible_host to private IP and ansible_user to azureuser
- [ ] #5 group_vars/all.yml defines global variables
- [ ] #6 requirements.yml lists azure.azcollection dependency
<!-- AC:END -->
