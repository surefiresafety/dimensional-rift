// Unity port of the Copy System: learned pool, four active slots, shared Spirit Energy.
using System;
using System.Collections.Generic;
using UnityEngine;

public enum Nature { Physical, Fire, Wind, Lightning, Earth, Water, Cursed }

public static class NatureWheel
{
    public static Nature Beats(Nature n) => n switch
    {
        Nature.Fire => Nature.Wind, Nature.Wind => Nature.Lightning, Nature.Lightning => Nature.Earth,
        Nature.Earth => Nature.Water, Nature.Water => Nature.Fire, _ => Nature.Physical
    };
    public static float Effectiveness(Nature attack, Nature defend)
    {
        bool a = attack != Nature.Physical && attack != Nature.Cursed;
        bool d = defend != Nature.Physical && defend != Nature.Cursed;
        if (!a || !d) return 1f;
        if (Beats(attack) == defend) return 2f;
        if (Beats(defend) == attack) return 0.5f;
        return 1f;
    }
}

[CreateAssetMenu(menuName = "Dimensional Rift/Ability")]
public class AbilityData : ScriptableObject
{
    public string abilityId;
    public string displayName;
    public Nature nature;
    public float basePower = 50f;
    public float spiritCost = 10f;
    public float cooldown = 2f;
    public GameObject payloadPrefab;   // spawned at activation; owns hitbox + VFX Graph effects
    public AnimationClip castClip;
}

public interface IExtractable { AbilityData GetExtractableAbility(); }

public class SpiritEnergy : MonoBehaviour
{
    public float max = 100f, current = 100f, regenPerSecond = 4f, regenDelay = 2.5f;
    public event Action<float, float> Changed;
    float regenBlockedUntil;
    public bool CanAfford(float c) => current >= c;
    public bool TrySpend(float c)
    {
        if (c < 0f || current < c) return false;
        current -= c; regenBlockedUntil = Time.time + regenDelay; Changed?.Invoke(current, max); return true;
    }
    public void Restore(float a) { current = Mathf.Min(max, current + a); Changed?.Invoke(current, max); }
    void Update() { if (current < max && Time.time >= regenBlockedUntil) Restore(regenPerSecond * Time.deltaTime); }
}

public class AbilityLoadout : MonoBehaviour
{
    public const int MaxSlots = 4;
    public List<AbilityData> learned = new();
    public AbilityData[] slots = new AbilityData[MaxSlots];
    public Transform spawnSocket;

    public event Action<AbilityData[]> LoadoutChanged;
    public event Action<AbilityData> AbilityLearned;

    SpiritEnergy spirit;
    readonly Dictionary<AbilityData, float> cooldownEnd = new();

    void Awake() => spirit = GetComponent<SpiritEnergy>();

    public bool Learn(AbilityData a)
    {
        if (!a || learned.Contains(a)) return false;
        learned.Add(a); AbilityLearned?.Invoke(a); Equip(a); return true;
    }

    public bool Equip(AbilityData a, int slot = -1)
    {
        if (!a || !learned.Contains(a) || Array.IndexOf(slots, a) >= 0) return false;
        if (slot < 0) { slot = Array.IndexOf(slots, null); if (slot < 0) return false; } // Rule of Four
        if (slot >= MaxSlots) return false;
        slots[slot] = a; LoadoutChanged?.Invoke(slots); return true;
    }

    public bool Unequip(int slot)
    {
        if (slot < 0 || slot >= MaxSlots || !slots[slot]) return false;
        slots[slot] = null; LoadoutChanged?.Invoke(slots); return true;
    }

    public AbilityData ExtractFrom(GameObject defeated)
    {
        var a = defeated.GetComponent<IExtractable>()?.GetExtractableAbility();
        return a && Learn(a) ? a : null;
    }

    public float CooldownRemaining(int slot) =>
        slots[slot] && cooldownEnd.TryGetValue(slots[slot], out var t) ? Mathf.Max(0f, t - Time.time) : 0f;

    public bool TryActivate(int slot)
    {
        var a = slot >= 0 && slot < MaxSlots ? slots[slot] : null;
        if (!a || CooldownRemaining(slot) > 0f) return false;
        if (spirit && !spirit.TrySpend(a.spiritCost)) return false;
        cooldownEnd[a] = Time.time + a.cooldown;
        if (a.payloadPrefab)
        {
            var t = spawnSocket ? spawnSocket : transform;
            var go = Instantiate(a.payloadPrefab, t.position, transform.rotation);
            go.SendMessage("OnActivatedBy", gameObject, SendMessageOptions.DontRequireReceiver);
        }
        return true;
    }
}
