package eu.emergingstandards.contextual_info;

import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

/**
 * Created by mike on 2/3/14.
 */
public enum EMSTContextualType {
    PERSON("Person", "psn"),
    PLACE("Place", "plc"),
    ORGANIZATION("Organization", "org"),
    GENRE("Genre", "gen");
//  BIBLIOGRAPHY("Bibliography", "bib"),
//  EVENT("Event", "evt");

    // Lookup table
    private static final Map<String, EMSTContextualType> lookup = new HashMap<>();

    static {
        for (EMSTContextualType contextualType : EMSTContextualType.values())
            lookup.put(contextualType.getKey(), contextualType);
    }

    @Nullable
    public static EMSTContextualType get(String key) {
        if (key != null) {
            return lookup.get(key);
        } else {
            return null;
        }
    }

    @NotNull
    public static Set<String> getKeys() {
        Set<String> keys = new HashSet<>();

        for (EMSTContextualType contextualType : EMSTContextualType.values()) {
            keys.add(contextualType.getKey());
        }
        return keys;
    }

    /* Instance members */

    private String name;
    private String key;

    private EMSTContextualType(String name, String key) {
        this.name = name;
        this.key = key;
    }

    public String getName() {
        return name;
    }

    public String getKey() {
        return key;
    }
}
