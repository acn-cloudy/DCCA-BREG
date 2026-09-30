public interface IEmailTemplatesSelector {
    EmailTemplate[] selectByDeveloperNames(Set<String> developerNames);
}