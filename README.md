# Ansible

You're right — it's redundant. `enable boot-start --accept-license --answer-yes --no-prompt` already accepts the licence, so the earlier `splunk start` isn't buying you licence acceptance.

Worse, the ordering is backwards. Splunk's own sequence is install → `enable boot-start -user splunk` → start via systemd. My version starts splunkd as the splunk user *before* boot-start has established that ownership, which on a fresh RPM install can fail on root-owned files.

The only thing the start/stop pair genuinely bought was **failing visibly in the Ansible run** if post-upgrade migration blows up, rather than systemd reporting a dead unit with the reason buried in splunkd.log. Not worth four tasks in a role this size.

Cut version:

```yaml
- name: Check whether install or upgrade is required # noqa: package-latest
  ansible.builtin.dnf:
    name: "{{ splunk_uf_pkg_name }}"
    state: latest
  check_mode: true
  register: splunk_uf_pending

- name: Install or upgrade forwarder # noqa: no-handler
  when: splunk_uf_pending is changed
  block:

    - name: Stop forwarder before the package transaction
      ansible.builtin.systemd:
        name: "{{ splunk_uf_service_name }}"
        state: stopped
      failed_when: false

    - name: Install or upgrade forwarder package # noqa: package-latest
      ansible.builtin.dnf:
        name: "{{ splunk_uf_pkg_name }}"
        state: latest

- name: Check for the generated systemd unit
  ansible.builtin.stat:
    path: "/etc/systemd/system/{{ splunk_uf_service_name }}.service"
  register: splunk_uf_unit

- name: Enable boot-start under systemd
  ansible.builtin.command:
    cmd: >-
      {{ splunk_uf_home }}/bin/splunk enable boot-start
      -systemd-managed 1
      -user {{ splunk_uf_user }}
      -group {{ splunk_uf_group }}
      --accept-license --answer-yes --no-prompt
  changed_when: true
  when: not splunk_uf_unit.stat.exists or splunk_uf_pending is changed

- name: Ensure forwarder is enabled and running
  ansible.builtin.systemd:
    name: "{{ splunk_uf_service_name }}"
    state: started
    enabled: true
    daemon_reload: true
```

Defaults unchanged. Seven tasks down to five.

**What I'd confirm on your build:** that the first `systemctl start` after a fresh install or an upgrade completes non-interactively — i.e. that licence acceptance persists from `enable boot-start`, and that post-upgrade migration runs cleanly under systemd with no TTY. That's the one assumption this simplification rests on. If migration turns out to need a TTY-attached start, the fix is a single `splunk start` *after* boot-start, not the pair I had.