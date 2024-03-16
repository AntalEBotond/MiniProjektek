import java.util.Random;
import java.util.Scanner;

public class Randi {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);
        Random random = new Random();
        int number = random.nextInt(100) + 1;
        int attempts = 0;

        while (true) {
            System.out.print("1 és 100 között: ");
            int guess = scanner.nextInt();
            attempts++;

            if (guess < number) {
                System.out.println("Kevés.");
            } else if (guess > number) {
                System.out.println("Sok.");
            } else {
                System.out.println("Talált! " + attempts + " lépés után.");
                break;
            }
        }
    }
}
