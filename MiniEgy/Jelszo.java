import java.util.Scanner;

public class Jelszo {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);
        String password = "jelszo";
        int attempts = 0;

        while (attempts < 3) {
            System.out.print("Add meg a jelszót: ");
            String userInput = scanner.nextLine();
            if (userInput.equals(password)) {
                System.out.println("Sikeres belépés!");
                break;
            } else {
                attempts++;
                System.out.println("Hibás jelszó!");
            }
        }

        if (attempts == 3) {
            System.out.println("Háromszor hibás jelszó!!!!");
        }
    }
}
