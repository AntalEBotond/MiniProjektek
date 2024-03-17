import java.util.Scanner;

public class ElsoEsUtolsoKarakter {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        System.out.println("Kérek egy szót:");
        String szo = scanner.nextLine();

        if (!szo.isEmpty()) {
            System.out.println("első karakter: " + szo.charAt(0));
            System.out.println("utolsó karakter: " + szo.charAt(szo.length() - 1));
        } else {
            System.out.println("üres.");
        }

        scanner.close();
    }
}

