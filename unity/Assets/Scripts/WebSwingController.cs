// Unity HDRP port of the web swing. Attach to a Rigidbody character (capsule, freeze rotation).
// Same model as the Unreal version: manual pendulum on the body's own velocity, rope as an
// inequality constraint, momentum preserved through release.
using UnityEngine;

[RequireComponent(typeof(Rigidbody))]
public class WebSwingController : MonoBehaviour
{
    [Header("Anchor search")]
    public Camera viewCamera;
    public LayerMask anchorLayers;          // tag buildings/anchors with this layer
    public float maxRopeLength = 35f;
    public float minAnchorHeight = 6f;
    public Vector2 searchElevation = new Vector2(25f, 80f);
    public float searchYawSpread = 35f;
    public int searchRays = 9;

    [Header("Swing feel")]
    public float swingGravityScale = 1.6f;
    public float pumpAcceleration = 18f;
    public float maxSwingSpeed = 42f;
    public float reelInSpeed = 7f;
    public float drag = 0.04f;
    public float releaseUpBoost = 4.5f;
    public float releaseMomentumScale = 1.15f;

    [Header("Presentation")]
    public LineRenderer webLine;
    public Transform handSocket;

    public bool IsSwinging { get; private set; }
    public Vector3 Anchor { get; private set; }
    public float RopeLength { get; private set; }

    Rigidbody rb;
    Vector2 moveInput;
    bool reelingIn;

    void Awake()
    {
        rb = GetComponent<Rigidbody>();
        if (!viewCamera) viewCamera = Camera.main;
        if (webLine) webLine.enabled = false;
    }

    // Hook these from the new Input System (PlayerInput "Send Messages") or call directly.
    public void OnMove(Vector2 v) => moveInput = v;
    public void OnReel(bool held) => reelingIn = held;

    public bool TryStartSwing()
    {
        if (IsSwinging) return false;
        if (!FindAnchor(out var anchor)) return false;
        StartSwingAt(anchor);
        return true;
    }

    public void StartSwingAt(Vector3 anchor)
    {
        Anchor = anchor;
        RopeLength = Mathf.Clamp(Vector3.Distance(rb.position, anchor), 3f, maxRopeLength);
        if (rb.linearVelocity.sqrMagnitude < 9f) rb.linearVelocity += transform.forward * 6f; // avoid the dead hang
        rb.useGravity = false;
        IsSwinging = true;
        if (webLine) webLine.enabled = true;
    }

    public void ReleaseSwing()
    {
        if (!IsSwinging) return;
        var v = rb.linearVelocity * releaseMomentumScale;
        v.y += releaseUpBoost;
        rb.linearVelocity = Vector3.ClampMagnitude(v, maxSwingSpeed * 1.25f);
        rb.useGravity = true;
        IsSwinging = false;
        reelingIn = false;
        if (webLine) webLine.enabled = false;
    }

    public bool FindAnchor(out Vector3 anchor)
    {
        anchor = default;
        var origin = rb.position;
        var fwd = Vector3.ProjectOnPlane(viewCamera.transform.forward, Vector3.up).normalized;
        if (fwd.sqrMagnitude < 0.01f) fwd = transform.forward;
        var travel = Vector3.ProjectOnPlane(rb.linearVelocity, Vector3.up).normalized;
        fwd = (fwd + travel * 0.5f).normalized;

        bool found = false; float best = float.MinValue;
        for (int i = 0; i < searchRays; i++)
        {
            float t = searchRays > 1 ? (float)i / (searchRays - 1) : 0.5f;
            float elev = Mathf.Lerp(searchElevation.x, searchElevation.y, t);
            foreach (float yaw in new[] { -searchYawSpread, 0f, searchYawSpread })
            {
                var dir = Quaternion.AngleAxis(yaw, Vector3.up) * Quaternion.AngleAxis(-elev, Vector3.Cross(Vector3.up, fwd)) * fwd;
                if (!Physics.Raycast(origin, dir, out var hit, maxRopeLength, anchorLayers, QueryTriggerInteraction.Ignore)) continue;
                var to = hit.point - origin;
                if (to.y < minAnchorHeight) continue;
                float score = to.y * 0.6f + Vector3.Dot(to, fwd) * 0.9f - to.magnitude * 0.25f;
                if (score > best) { best = score; anchor = hit.point; found = true; }
            }
        }
        return found;
    }

    void FixedUpdate()
    {
        if (!IsSwinging) return;
        float dt = Time.fixedDeltaTime;
        var v = rb.linearVelocity;

        // Forces
        v += Physics.gravity * swingGravityScale * dt;
        if (moveInput.sqrMagnitude > 0.01f)
        {
            var camF = Vector3.ProjectOnPlane(viewCamera.transform.forward, Vector3.up).normalized;
            var camR = Vector3.Cross(Vector3.up, camF);
            var pump = (camF * moveInput.y + camR * moveInput.x).normalized;
            v += pump * pumpAcceleration * dt;
        }
        v *= Mathf.Max(0f, 1f - drag * dt);
        if (reelingIn) RopeLength = Mathf.Max(3f, RopeLength - reelInSpeed * dt);

        // Rope tension: kill outward radial velocity at full extension
        var toAnchor = Anchor - rb.position;
        float dist = toAnchor.magnitude;
        if (dist > 1e-4f)
        {
            var radial = toAnchor / dist;
            float outward = Vector3.Dot(v, -radial);
            if (dist >= RopeLength - 0.01f && outward > 0f) v += radial * outward;
        }
        v = Vector3.ClampMagnitude(v, maxSwingSpeed);

        // Integrate, then project back onto the sphere
        var newPos = rb.position + v * dt;
        var toAnchorNow = Anchor - newPos;
        if (toAnchorNow.magnitude > RopeLength) newPos = Anchor - toAnchorNow.normalized * RopeLength;
        rb.linearVelocity = (newPos - rb.position) / dt;
        rb.MovePosition(newPos);

        // Face travel direction
        var flat = Vector3.ProjectOnPlane(rb.linearVelocity, Vector3.up);
        if (flat.sqrMagnitude > 0.25f)
            rb.MoveRotation(Quaternion.Slerp(rb.rotation, Quaternion.LookRotation(flat), 10f * dt));

        if (newPos.y > Anchor.y) ReleaseSwing(); // looped over the top

        if (webLine)
        {
            webLine.SetPosition(0, handSocket ? handSocket.position : rb.position);
            webLine.SetPosition(1, Anchor);
        }
    }

    void OnCollisionEnter(Collision c)
    {
        // Swung into a walkable surface: land.
        if (IsSwinging && c.contacts.Length > 0 && c.contacts[0].normal.y > 0.6f) ReleaseSwing();
    }
}
