package eu.nebulous.enums;
public enum StatusEnum {

    SUCCESS("Success"),
    FAILURE("Failure");

    private final String description;

    StatusEnum(String description) {
        this.description = description;
    }

    public String getDescription() {
        return this.description;
    }
}
